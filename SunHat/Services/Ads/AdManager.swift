//
//  AdManager.swift
//  SunHat
//
//  Entitlement-gated wrapper around the Google Mobile Ads SDK. The SDK is
//  never started — no network activity, no ad requests — unless entitlement
//  allows ads: affirmatively non-entitled, or (only while live resolution is
//  still pending at launch) the UserDefaults-mirrored last-known state says
//  non-entitled. Info.plist sets GADDelayAppMeasurementInit so nothing runs
//  before start() either.
//
//  Consent & tracking order per Google's guidance: UMP consent (EEA/UK form
//  when required) → App Tracking Transparency → SDK start, with the SDK
//  gated on ConsentInformation.canRequestAds. ATT is deferred past the first
//  session and only requested while the scene is active — see
//  AdActivationPolicy for the exact rules.
//
//  Observes StoreManager's entitlement state directly, so a mid-session
//  purchase immediately flips shouldShowAdSlots and every banner slot
//  disappears.
//

import Foundation
import AppTrackingTransparency
import GoogleMobileAds
import UserMessagingPlatform
import UIKit
import os

@MainActor
protocol TrackingAuthorizing: AnyObject {
    var statusKind: TrackingStatusKind { get }
    func requestAuthorization() async
}

@MainActor
final class SystemTrackingAuthorizer: TrackingAuthorizing {
    var statusKind: TrackingStatusKind {
        switch ATTrackingManager.trackingAuthorizationStatus {
        case .notDetermined: .notDetermined
        case .restricted: .restricted
        case .denied: .denied
        case .authorized: .authorized
        @unknown default: .denied
        }
    }

    func requestAuthorization() async {
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }
}

@MainActor
@Observable
final class AdManager {
    static let shared = AdManager()

    /// The SDK has been started this process. Never reset — stopping the SDK
    /// isn't supported; ad-free is enforced by shouldShowAdSlots and by
    /// banner slots not existing.
    private(set) var isStarted = false

    /// Mirrors the real scene phase; the ATT prompt is only ever attempted
    /// while active (the system silently ignores it otherwise).
    private(set) var isSceneActive = false

    /// AppLifecyclePromptCoordinator increments this once per foreground
    /// session; reusing it keeps "never on first launch" aligned with the
    /// app's existing definition of a session.
    private static let appOpenCountKey = "appLifecyclePrompt.appOpenCount"

    /// QA seam: UI tests that exercise StoreKit purchase flows pass this to
    /// keep the ad SDK entirely off — on the iOS 27 beta simulator, Google
    /// Mobile Ads' storekitd interaction can wedge the StoreKit-Testing
    /// storefront ("Subscription Unavailable"). Never set in production.
    private static let isDisabledForUITesting =
        ProcessInfo.processInfo.arguments.contains("-sunhatDisableAdSDK")

    private let userDefaults: UserDefaults
    private let tracking: TrackingAuthorizing
    private let startSDK: () -> Void
    private var isEvaluating = false
    private let logger = Logger(subsystem: "org.wesley.sunhat", category: "AdManager")

    convenience init() {
        self.init(
            userDefaults: .standard,
            tracking: SystemTrackingAuthorizer(),
            startSDK: { MobileAds.shared.start() }
        )
    }

    /// Test seam; production uses `.shared`.
    init(userDefaults: UserDefaults, tracking: TrackingAuthorizing, startSDK: @escaping () -> Void) {
        self.userDefaults = userDefaults
        self.tracking = tracking
        self.startSDK = startSDK
    }

    /// Live entitlement when resolved; last-known mirror while it's pending.
    private var effectiveAllowsAdRequests: Bool {
        AdActivationPolicy.effectiveAllowsAdRequests(
            live: StoreManager.shared.entitlementState,
            cached: StoreManager.cachedEntitlementState(userDefaults: userDefaults)
        )
    }

    /// Set from the concurrent consent gather: true only when the consent
    /// framework answered AND says ads may not be requested (EEA user who
    /// hasn't consented). Unreachable UMP leaves it false — Google enforces
    /// EEA rules server-side too, and the gate applies whenever UMP answers.
    private(set) var consentBlocksAds = false

    /// Single source of truth for every banner slot. Reactive through both
    /// this manager's and StoreManager's observation.
    var shouldShowAdSlots: Bool {
        isStarted && effectiveAllowsAdRequests && !consentBlocksAds
    }

    /// True when Google's consent framework requires a reachable
    /// privacy-options entry point (EEA/UK users); Settings shows a row.
    var privacyOptionsRequired: Bool {
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    /// Idempotent launch hook: applies the current entitlement and re-arms
    /// observation so later entitlement changes (purchase, restore, expiry)
    /// re-evaluate automatically. The scene isn't active yet during App.init,
    /// so ATT is never requested from here — the foreground hook handles it.
    func activate() {
        evaluateActivation()
        observeEntitlement()
    }

    /// Called from the scenePhase hook on every phase change.
    func sceneDidChange(active: Bool) {
        isSceneActive = active
        if active {
            evaluateActivation()
            // A consent form that couldn't present earlier (e.g. a system
            // permission alert was up) gets another chance each foreground.
            if isStarted && consentBlocksAds {
                Task { await gatherConsentConcurrently() }
            }
        }
    }

    func evaluateActivation() {
        guard !Self.isDisabledForUITesting else { return }
        guard !isEvaluating else { return }
        isEvaluating = true

        let decision = AdActivationPolicy.decide(
            allowsAdRequests: effectiveAllowsAdRequests,
            sdkStarted: isStarted,
            trackingStatus: tracking.statusKind,
            appOpenCount: userDefaults.integer(forKey: Self.appOpenCountKey),
            isSceneActive: isSceneActive
        )

        guard decision != .none else {
            isEvaluating = false
            return
        }

        // This Task must contain NO network awaits: a hung endpoint would
        // wedge isEvaluating for the whole session. ATT is a local system
        // prompt; consent gathering runs concurrently and gates the ad SLOTS
        // via consentBlocksAds when it answers.
        Task {
            defer { isEvaluating = false }

            if decision.shouldRequestTracking {
                await tracking.requestAuthorization()
            }
            // Re-check entitlement after the prompt: the user may have become
            // Ad-Free while it was up.
            if decision.shouldStartSDK, effectiveAllowsAdRequests {
                startSDK()
                isStarted = true
                logger.info("Google Mobile Ads SDK started (user is not Ad-Free)")
                Task { await self.gatherConsentConcurrently() }
            }
        }
    }

    /// Presents Google's privacy-options form (consent revocation) for users
    /// in regions where it's required.
    func presentPrivacyOptions() {
        guard let rootViewController = Self.rootViewController() else { return }
        ConsentForm.presentPrivacyOptionsForm(from: rootViewController) { [logger] error in
            if let error {
                logger.error("Privacy options form failed: \(error.localizedDescription)")
            }
        }
    }

    /// Google EU User Consent Policy: a certified CMP must gather consent
    /// before ads serve to EEA/UK users. Elsewhere this resolves quickly with
    /// canRequestAds == true and no form.
    /// Runs concurrently with (never blocking) the activation pipeline.
    /// When Google's consent framework answers, its verdict gates the ad
    /// slots via consentBlocksAds and presents the EEA form when required.
    private func gatherConsentConcurrently() async {
        let parameters = RequestParameters()
        #if DEBUG
        // Simulator/dev runs use Google's sample app ID, which has no
        // published consent message — UMP then reports consent "required"
        // with no form to satisfy it, blocking every ad. Debug geography
        // makes dev behave like a production non-EEA user; Release builds
        // use real geography against the real AdMob app's consent message.
        let debugSettings = DebugSettings()
        debugSettings.geography = .notEEA
        parameters.debugSettings = debugSettings
        #endif
        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)
        } catch {
            logger.error("Consent info update failed: \(error.localizedDescription); slots stay gated by entitlement only")
            return
        }

        consentBlocksAds = !ConsentInformation.shared.canRequestAds
        logger.info("Ad consent resolved: canRequestAds=\(ConsentInformation.shared.canRequestAds)")

        // Only attempt presentation when a form is actually required and the
        // UI can host it — loadAndPresentIfRequired can otherwise throw
        // spurious presentation errors at cold launch.
        guard ConsentInformation.shared.consentStatus == .required, isSceneActive else { return }
        // Retry a few times: at launch a system permission alert (location,
        // notifications) is often mid-presentation and UIKit refuses a second
        // presented controller.
        for attempt in 1...3 {
            guard let rootViewController = Self.rootViewController() else { return }
            do {
                try await ConsentForm.loadAndPresentIfRequired(from: rootViewController)
                consentBlocksAds = !ConsentInformation.shared.canRequestAds
                logger.info("Consent form flow finished: canRequestAds=\(ConsentInformation.shared.canRequestAds)")
                return
            } catch {
                logger.error("Consent form presentation attempt \(attempt) failed: \(error.localizedDescription)")
                try? await Task.sleep(for: .seconds(4))
            }
        }
    }

    private static func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    }

    private func observeEntitlement() {
        withObservationTracking {
            _ = StoreManager.shared.entitlementState
        } onChange: {
            Task { @MainActor in
                AdManager.shared.evaluateActivation()
                AdManager.shared.observeEntitlement()
            }
        }
    }
}
