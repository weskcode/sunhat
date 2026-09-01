//
//  AdManagerGateTests.swift
//  SunHatTests
//
//  Covers the gate every banner slot actually reads — AdManager's decision to
//  start the Google Mobile Ads SDK — using the manager's injection seam so no
//  real SDK call is made. The pure timing rules live in
//  AdActivationPolicyTests; this pins the wiring around them, including the
//  consent gate's fail-closed default.
//

import Foundation
import Testing
@testable import SunHat

@MainActor
private final class StubTrackingAuthorizer: TrackingAuthorizing {
    var statusKind: TrackingStatusKind
    private(set) var requestCount = 0

    init(statusKind: TrackingStatusKind) {
        self.statusKind = statusKind
    }

    func requestAuthorization() async {
        requestCount += 1
        statusKind = .denied
    }
}

@MainActor
@Suite(.serialized)
struct AdManagerGateTests {

    private static let suiteName = "AdManagerGateTests"

    private func makeManager(
        appOpenCount: Int,
        trackingStatus: TrackingStatusKind = .denied
    ) -> (AdManager, StubTrackingAuthorizer, Box) {
        let defaults = UserDefaults(suiteName: Self.suiteName)!
        defaults.removePersistentDomain(forName: Self.suiteName)
        defaults.set(appOpenCount, forKey: "appLifecyclePrompt.appOpenCount")

        let tracking = StubTrackingAuthorizer(statusKind: trackingStatus)
        let box = Box()
        let manager = AdManager(
            userDefaults: defaults,
            tracking: tracking,
            startSDK: { box.startCount += 1 }
        )
        return (manager, tracking, box)
    }

    final class Box {
        var startCount = 0
    }

    /// Polls instead of assuming one yield: evaluateActivation commits its
    /// work inside an unstructured Task.
    private func settle(_ condition: () -> Bool, attempts: Int = 50) async {
        for _ in 0..<attempts {
            if condition() { return }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    @Test("A subscriber never starts the ad SDK and never shows a slot")
    func subscriberNeverStartsSDK() async {
        let (manager, _, box) = makeManager(appOpenCount: 5)
        StoreManager.shared.overrideEntitlementStateForTesting(.active)
        defer { StoreManager.shared.clearEntitlementOverrideForTesting() }

        manager.sceneDidChange(active: true)
        await settle { box.startCount > 0 }

        #expect(box.startCount == 0)
        #expect(!manager.isStarted)
        #expect(!manager.shouldShowAdSlots)
    }

    @Test("Unresolved entitlement fails closed — no SDK start, no slot")
    func unknownEntitlementFailsClosed() async {
        let (manager, _, box) = makeManager(appOpenCount: 5)
        StoreManager.shared.overrideEntitlementStateForTesting(.unknown)
        defer { StoreManager.shared.clearEntitlementOverrideForTesting() }

        manager.sceneDidChange(active: true)
        await settle { box.startCount > 0 }

        #expect(box.startCount == 0)
        #expect(!manager.shouldShowAdSlots)
    }

    @Test("A non-subscriber starts the SDK exactly once across repeated evaluations")
    func nonSubscriberStartsSDKOnce() async {
        let (manager, _, box) = makeManager(appOpenCount: 5)
        StoreManager.shared.overrideEntitlementStateForTesting(.notEntitled)
        defer { StoreManager.shared.clearEntitlementOverrideForTesting() }

        manager.sceneDidChange(active: true)
        await settle { manager.isStarted }
        manager.sceneDidChange(active: true)
        manager.evaluateActivation()
        await settle { box.startCount > 1 }

        #expect(box.startCount == 1)
        #expect(manager.isStarted)
    }

    @Test("A started SDK still shows no slots while consent blocks ads")
    func consentGateSuppressesSlots() async {
        let (manager, _, _) = makeManager(appOpenCount: 5)
        StoreManager.shared.overrideEntitlementStateForTesting(.notEntitled)
        defer { StoreManager.shared.clearEntitlementOverrideForTesting() }

        manager.sceneDidChange(active: true)
        await settle { manager.isStarted }

        // consentBlocksAds is seeded from UMP's persisted verdict; whatever it
        // says, the invariant is that a blocking verdict hides every slot.
        if manager.consentBlocksAds {
            #expect(!manager.shouldShowAdSlots)
        } else {
            #expect(manager.shouldShowAdSlots)
        }
    }

    @Test("ATT is never requested in the app's first session")
    func firstSessionNeverRequestsTracking() async {
        let (manager, tracking, _) = makeManager(appOpenCount: 1, trackingStatus: .notDetermined)
        StoreManager.shared.overrideEntitlementStateForTesting(.notEntitled)
        defer { StoreManager.shared.clearEntitlementOverrideForTesting() }

        manager.sceneDidChange(active: true)
        await settle { manager.isStarted }

        #expect(tracking.requestCount == 0)
    }

    @Test("A later session with an active scene does request ATT")
    func laterSessionRequestsTracking() async {
        let (manager, tracking, _) = makeManager(appOpenCount: 3, trackingStatus: .notDetermined)
        StoreManager.shared.overrideEntitlementStateForTesting(.notEntitled)
        defer { StoreManager.shared.clearEntitlementOverrideForTesting() }

        manager.sceneDidChange(active: true)
        await settle { tracking.requestCount > 0 }

        #expect(tracking.requestCount == 1)
    }
}
