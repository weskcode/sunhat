//
//  AdActivationPolicy.swift
//  SunHat
//
//  Pure decision logic for when the ad SDK may start and when the App
//  Tracking Transparency prompt may be shown. StoreKit-free and UIKit-free so
//  it is unit-testable; AdManager feeds it live values and applies the result.
//
//  Rules encoded here:
//  - Nothing happens unless entitlement affirmatively allows ad requests
//    (unknown fails closed — a subscriber never triggers ad machinery).
//  - The ATT prompt is never shown during the app's first session, and only
//    while the scene is active (the system ignores it otherwise).
//  - The SDK may start without tracking authorization (ads simply serve
//    non-personalized); a deferred ATT request can still happen in a later
//    session after the SDK is already running.
//

import Foundation

/// ATTrackingManager.AuthorizationStatus reduced to a framework-free value.
nonisolated enum TrackingStatusKind: Sendable, Equatable {
    case notDetermined
    case restricted
    case denied
    case authorized
}

nonisolated struct AdActivationDecision: Sendable, Equatable {
    var shouldRequestTracking: Bool
    var shouldStartSDK: Bool

    static let none = AdActivationDecision(shouldRequestTracking: false, shouldStartSDK: false)
}

nonisolated enum AdActivationPolicy {
    /// A cached free-tier state can predate a purchase on another device.
    /// Wait for this launch's StoreKit resolution before allowing ad requests.
    static func effectiveAllowsAdRequests(
        live: AdFreeEntitlementState,
        cached _: AdFreeEntitlementState
    ) -> Bool {
        live.allowsAdRequests
    }

    static func decide(
        allowsAdRequests: Bool,
        sdkStarted: Bool,
        trackingStatus: TrackingStatusKind,
        appOpenCount: Int,
        isSceneActive: Bool
    ) -> AdActivationDecision {
        guard allowsAdRequests else { return .none }

        let shouldRequestTracking = trackingStatus == .notDetermined
            && appOpenCount >= 2
            && isSceneActive

        return AdActivationDecision(
            shouldRequestTracking: shouldRequestTracking,
            shouldStartSDK: !sdkStarted
        )
    }
}
