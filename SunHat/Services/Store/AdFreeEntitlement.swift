//
//  AdFreeEntitlement.swift
//  SunHat
//
//  Pure entitlement model for the "SunHat Ad-Free" subscription group.
//  The resolver is deliberately free of StoreKit types so the state mapping
//  (active / grace period / billing retry / expired) is unit-testable without
//  a StoreKit test session. StoreManager feeds it values derived from
//  Transaction.currentEntitlements and Product.SubscriptionInfo.status.
//

import Foundation

// The app target compiles with default MainActor isolation
// (SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor); these are pure Sendable value
// types callable from any context, so they opt out explicitly.

/// The renewal states StoreKit can report for a subscription in the group,
/// reduced to a StoreKit-free value type.
nonisolated enum SubscriptionRenewalStateKind: Sendable, Equatable {
    case subscribed
    case expired
    case inBillingRetryPeriod
    case inGracePeriod
    case revoked
}

/// The single source of truth every ad placement and the paywall read from.
nonisolated enum AdFreeEntitlementState: String, Sendable, Equatable, Codable {
    /// Not yet resolved this launch (StoreKit hasn't answered).
    case unknown
    /// Affirmatively not subscribed (never bought, or fully expired).
    case notEntitled
    /// Subscribed and in good standing.
    case active
    /// A renewal payment failed but Apple's billing grace period is active —
    /// the user keeps paid access while Apple retries the charge.
    case gracePeriod
    /// Grace exhausted; Apple is still retrying billing but paid access has
    /// lapsed. Settings surfaces a fix-billing prompt in this state.
    case billingRetry

    /// True when the user has paid access, so ads must be off.
    var isAdFree: Bool {
        self == .active || self == .gracePeriod
    }

    /// Ads may be requested only on affirmative non-entitlement. `.unknown`
    /// fails closed (no ad request) so a subscriber never sees an ad flash
    /// while entitlements are still resolving at launch.
    var allowsAdRequests: Bool {
        self == .notEntitled || self == .billingRetry
    }
}

nonisolated enum AdFreeEntitlementResolver {
    /// Maps what StoreKit reported to the app-facing entitlement state.
    ///
    /// - Parameters:
    ///   - hasVerifiedEntitlement: a verified, non-revoked transaction for an
    ///     Ad-Free product appeared in `Transaction.currentEntitlements`.
    ///   - renewalStates: subscription-group statuses, when they could be
    ///     fetched (empty when offline or products failed to load).
    static func resolve(
        hasVerifiedEntitlement: Bool,
        renewalStates: [SubscriptionRenewalStateKind]
    ) -> AdFreeEntitlementState {
        if renewalStates.contains(.subscribed) {
            return .active
        }
        if renewalStates.contains(.inGracePeriod) {
            return .gracePeriod
        }
        if renewalStates.contains(.inBillingRetryPeriod) {
            return .billingRetry
        }
        // An affirmative, verified terminal status outranks the entitlement
        // snapshot: the snapshot is captured before the status fetch, so after
        // a refund or expiry the status is the fresher signal.
        if renewalStates.contains(.revoked) || renewalStates.contains(.expired) {
            return .notEntitled
        }
        // No status information at all (offline, products not loaded): the
        // verified entitlement snapshot is authoritative — favor the paying user.
        if hasVerifiedEntitlement {
            return .active
        }
        return .notEntitled
    }
}
