//
//  AdActivationPolicyTests.swift
//  SunHatTests
//
//  Pins the ad-SDK activation and App Tracking Transparency timing rules:
//  nothing runs for Ad-Free or unresolved users, ATT is never requested in
//  the app's first session or while the scene is inactive, and the SDK can
//  start without tracking authorization (with ATT still requestable later).
//

import Foundation
import Testing
@testable import SunHat

struct AdActivationPolicyTests {

    @Test("Ad-Free or unresolved entitlement triggers nothing at all")
    func entitledUserTriggersNothing() {
        let decision = AdActivationPolicy.decide(
            allowsAdRequests: false,
            sdkStarted: false,
            trackingStatus: .notDetermined,
            appOpenCount: 10,
            isSceneActive: true
        )
        #expect(decision == .none)
        #expect(!decision.shouldRequestTracking)
        #expect(!decision.shouldStartSDK)
    }

    @Test("First session starts the SDK without an ATT prompt")
    func firstSessionSkipsTracking() {
        let decision = AdActivationPolicy.decide(
            allowsAdRequests: true,
            sdkStarted: false,
            trackingStatus: .notDetermined,
            appOpenCount: 1,
            isSceneActive: true
        )
        #expect(!decision.shouldRequestTracking)
        #expect(decision.shouldStartSDK)
    }

    @Test("Second session with an active scene requests ATT and starts the SDK")
    func secondSessionRequestsTracking() {
        let decision = AdActivationPolicy.decide(
            allowsAdRequests: true,
            sdkStarted: false,
            trackingStatus: .notDetermined,
            appOpenCount: 2,
            isSceneActive: true
        )
        #expect(decision.shouldRequestTracking)
        #expect(decision.shouldStartSDK)
    }

    @Test("ATT is never requested while the scene is inactive")
    func inactiveSceneDefersTracking() {
        let decision = AdActivationPolicy.decide(
            allowsAdRequests: true,
            sdkStarted: false,
            trackingStatus: .notDetermined,
            appOpenCount: 5,
            isSceneActive: false
        )
        #expect(!decision.shouldRequestTracking)
        #expect(decision.shouldStartSDK)
    }

    @Test("A determined ATT status is never re-prompted",
          arguments: [TrackingStatusKind.denied, .authorized, .restricted])
    func determinedStatusNeverPrompts(status: TrackingStatusKind) {
        let decision = AdActivationPolicy.decide(
            allowsAdRequests: true,
            sdkStarted: false,
            trackingStatus: status,
            appOpenCount: 5,
            isSceneActive: true
        )
        #expect(!decision.shouldRequestTracking)
        #expect(decision.shouldStartSDK)
    }

    @Test("A running SDK can still pick up a deferred ATT request")
    func deferredTrackingAfterSDKStart() {
        let decision = AdActivationPolicy.decide(
            allowsAdRequests: true,
            sdkStarted: true,
            trackingStatus: .notDetermined,
            appOpenCount: 3,
            isSceneActive: true
        )
        #expect(decision.shouldRequestTracking)
        #expect(!decision.shouldStartSDK)
    }

    @Test("While live entitlement is unknown, the cached mirror decides ad eligibility",
          arguments: [
            (AdFreeEntitlementState.unknown, AdFreeEntitlementState.notEntitled, true),
            (.unknown, .active, false),
            (.unknown, .unknown, false),
            (.unknown, .billingRetry, true),
            (.active, .notEntitled, false),
            (.notEntitled, .active, true),
            (.gracePeriod, .notEntitled, false)
          ])
    func cachedMirrorGatesLaunch(live: AdFreeEntitlementState, cached: AdFreeEntitlementState, expected: Bool) {
        #expect(AdActivationPolicy.effectiveAllowsAdRequests(live: live, cached: cached) == expected)
    }

    @Test("A running SDK with determined ATT has nothing left to do")
    func steadyStateIsNone() {
        let decision = AdActivationPolicy.decide(
            allowsAdRequests: true,
            sdkStarted: true,
            trackingStatus: .authorized,
            appOpenCount: 3,
            isSceneActive: true
        )
        #expect(decision == .none)
    }
}
