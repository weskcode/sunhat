//
//  AdFreeEntitlementResolverTests.swift
//  SunHatTests
//
//  Exhaustive coverage of the StoreKit-free entitlement mapping: which
//  combinations of currentEntitlements presence and subscription renewal
//  states produce active / grace / billing-retry / not-entitled, and the two
//  derived gates (isAdFree, allowsAdRequests). The launch-safety invariant —
//  ads are only ever requested on affirmative non-entitlement — is pinned here.
//

import Foundation
import Testing
@testable import SunHat

struct AdFreeEntitlementResolverTests {

    // MARK: - State resolution

    @Test("Subscribed status resolves to active")
    func subscribedResolvesActive() {
        let state = AdFreeEntitlementResolver.resolve(
            hasVerifiedEntitlement: true,
            renewalStates: [.subscribed]
        )
        #expect(state == .active)
    }

    @Test("Grace period keeps the user entitled but is labeled gracePeriod")
    func gracePeriodResolves() {
        let state = AdFreeEntitlementResolver.resolve(
            hasVerifiedEntitlement: true,
            renewalStates: [.inGracePeriod]
        )
        #expect(state == .gracePeriod)
        #expect(state.isAdFree)
        #expect(!state.allowsAdRequests)
    }

    @Test("Billing retry without a current entitlement is not ad-free")
    func billingRetryResolves() {
        let state = AdFreeEntitlementResolver.resolve(
            hasVerifiedEntitlement: false,
            renewalStates: [.inBillingRetryPeriod]
        )
        #expect(state == .billingRetry)
        #expect(!state.isAdFree)
        #expect(state.allowsAdRequests)
    }

    @Test("Expired subscription with no entitlement resolves to notEntitled")
    func expiredResolvesNotEntitled() {
        let state = AdFreeEntitlementResolver.resolve(
            hasVerifiedEntitlement: false,
            renewalStates: [.expired]
        )
        #expect(state == .notEntitled)
        #expect(state.allowsAdRequests)
    }

    @Test("Revoked subscription with no entitlement resolves to notEntitled")
    func revokedResolvesNotEntitled() {
        let state = AdFreeEntitlementResolver.resolve(
            hasVerifiedEntitlement: false,
            renewalStates: [.revoked]
        )
        #expect(state == .notEntitled)
    }

    @Test("No StoreKit data at all resolves to notEntitled")
    func noDataResolvesNotEntitled() {
        let state = AdFreeEntitlementResolver.resolve(
            hasVerifiedEntitlement: false,
            renewalStates: []
        )
        #expect(state == .notEntitled)
    }

    @Test("Entitlement with unavailable status (offline) favors the paying user")
    func entitlementWithoutStatusResolvesActive() {
        let state = AdFreeEntitlementResolver.resolve(
            hasVerifiedEntitlement: true,
            renewalStates: []
        )
        #expect(state == .active)
        #expect(state.isAdFree)
    }

    @Test("An affirmative expired status outranks a stale entitlement snapshot")
    func expiredStatusOutranksStaleSnapshot() {
        // The entitlement snapshot is captured before the status fetch, so a
        // terminal status is always the fresher signal (refund/expiry race).
        let state = AdFreeEntitlementResolver.resolve(
            hasVerifiedEntitlement: true,
            renewalStates: [.expired]
        )
        #expect(state == .notEntitled)
    }

    @Test("An affirmative revoked status outranks a stale entitlement snapshot")
    func revokedStatusOutranksStaleSnapshot() {
        let state = AdFreeEntitlementResolver.resolve(
            hasVerifiedEntitlement: true,
            renewalStates: [.revoked]
        )
        #expect(state == .notEntitled)
    }

    @Test("Billing retry outranks a stale entitlement snapshot")
    func billingRetryOutranksStaleSnapshot() {
        let state = AdFreeEntitlementResolver.resolve(
            hasVerifiedEntitlement: true,
            renewalStates: [.inBillingRetryPeriod]
        )
        #expect(state == .billingRetry)
    }

    @Test("Subscribed outranks other states when both plans report (crossgrade)")
    func subscribedOutranksExpired() {
        let state = AdFreeEntitlementResolver.resolve(
            hasVerifiedEntitlement: true,
            renewalStates: [.expired, .subscribed]
        )
        #expect(state == .active)
    }

    // MARK: - Gate invariants

    @Test("Unknown fails closed: no paid access claimed, but no ad requests either")
    func unknownFailsClosed() {
        let state = AdFreeEntitlementState.unknown
        #expect(!state.isAdFree)
        #expect(!state.allowsAdRequests)
    }

    @Test("Ads are only ever requested on affirmative non-entitlement",
          arguments: [
            AdFreeEntitlementState.unknown,
            .notEntitled,
            .active,
            .gracePeriod,
            .billingRetry
          ])
    func adRequestsRequireAffirmativeNonEntitlement(state: AdFreeEntitlementState) {
        // A state never both grants ad-free and allows ad requests, and ad
        // requests are allowed only for notEntitled / billingRetry.
        #expect(!(state.isAdFree && state.allowsAdRequests))
        #expect(state.allowsAdRequests == (state == .notEntitled || state == .billingRetry))
    }

    // MARK: - Cached-state launch gate

    @Test("Cached entitlement round-trips through UserDefaults")
    func cachedStateRoundTrip() async {
        let defaults = UserDefaults(suiteName: "AdFreeEntitlementResolverTests")!
        defer { defaults.removePersistentDomain(forName: "AdFreeEntitlementResolverTests") }

        defaults.set(AdFreeEntitlementState.active.rawValue, forKey: StoreManager.cachedEntitlementStateKey)
        #expect(StoreManager.cachedEntitlementState(userDefaults: defaults) == .active)

        defaults.set("garbage-value", forKey: StoreManager.cachedEntitlementStateKey)
        #expect(StoreManager.cachedEntitlementState(userDefaults: defaults) == .unknown)

        defaults.removeObject(forKey: StoreManager.cachedEntitlementStateKey)
        #expect(StoreManager.cachedEntitlementState(userDefaults: defaults) == .unknown)
    }
}
