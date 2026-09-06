//
//  StoreManager.swift
//  SunHat
//
//  StoreKit 2 manager for the "SunHat Ad-Free" subscription group: loads the
//  two products, derives the app-wide entitlement state from
//  Transaction.currentEntitlements + subscription status, listens to
//  Transaction.updates so renewals/refunds/Ask-to-Buy approvals land without a
//  relaunch, and handles purchase + restore.
//
//  Shared like the other services (`.shared`), and additionally injected via
//  `.environment(StoreManager.shared)` at the app root so views read it with
//  `@Environment(StoreManager.self)`.
//

import Foundation
import StoreKit
import os

@MainActor
@Observable
final class StoreManager {
    static let shared = StoreManager()

    /// Product identifiers are developer-chosen, so these exact IDs can be
    /// created verbatim in App Store Connect later — no code change needed.
    nonisolated enum ProductID {
        static let monthly = "org.wesley.sunhat.adfree.monthly"
        static let yearly = "org.wesley.sunhat.adfree.yearly"
        static let all: [String] = [monthly, yearly]
    }

    enum PurchaseOutcome: Sendable, Equatable {
        case success
        /// Deferred (e.g. Ask to Buy) — entitlement arrives via Transaction.updates.
        case pending
        case cancelled
    }

    enum StoreError: LocalizedError {
        case failedVerification

        var errorDescription: String? {
            String(localized: "The App Store could not verify this purchase.", comment: "Error shown when a StoreKit transaction fails local verification")
        }
    }

    /// How cryptographic verification failures from StoreKit are treated.
    enum TransactionTrustPolicy: Sendable, Equatable {
        /// Production: only transactions Apple's verifier accepts count.
        case verifiedOnly
        /// StoreKit-Testing seam: xcodebuild-run unit tests drive an
        /// SKTestSession whose transactions are signed with a local test
        /// certificate this process doesn't trust, so they arrive as
        /// .unverified(_, .invalidSignature). Accepting exactly that failure
        /// keeps the integration tests meaningful. Only the test target passes
        /// this; every production path uses the default `.verifiedOnly`.
        case acceptTestSignatures
    }

    /// Last-known entitlement, mirrored to UserDefaults. Consulted only to
    /// decide whether ad-SDK startup may proceed before the first StoreKit
    /// resolution of a launch; never trusted to grant paid access.
    nonisolated static let cachedEntitlementStateKey = "entitlement.adFree.state"

    /// Test-only entitlement override, so gate tests can pin a state without
    /// driving the App Store. Never set in production.
    private var entitlementOverrideForTesting: AdFreeEntitlementState?

    func overrideEntitlementStateForTesting(_ state: AdFreeEntitlementState) {
        entitlementOverrideForTesting = state
        entitlementState = state
    }

    func clearEntitlementOverrideForTesting() {
        entitlementOverrideForTesting = nil
        entitlementState = .unknown
    }

    private(set) var products: [Product] = []
    private(set) var productsLoadFailed = false
    private(set) var entitlementState: AdFreeEntitlementState = .unknown
    private(set) var activeProductID: String?
    private(set) var expirationDate: Date?
    private(set) var willAutoRenew: Bool?

    var isAdFree: Bool { entitlementState.isAdFree }
    var allowsAdRequests: Bool { entitlementState.allowsAdRequests }

    var activePlanDisplayName: String? {
        switch activeProductID {
        case ProductID.monthly:
            String(localized: "Monthly", comment: "Name of the monthly Ad-Free plan shown in Settings")
        case ProductID.yearly:
            String(localized: "Annual", comment: "Name of the annual Ad-Free plan shown in Settings")
        default:
            nil
        }
    }

    private let userDefaults: UserDefaults
    private var updatesTask: Task<Void, Never>?
    private var statusUpdatesTask: Task<Void, Never>?
    /// Bumped at each refreshEntitlement entry; a run that was overtaken while
    /// suspended discards its result instead of clobbering the newer one.
    private var refreshGeneration = 0
    private let logger = Logger(subsystem: "org.wesley.sunhat", category: "StoreManager")

    private let trustPolicy: TransactionTrustPolicy

    convenience init() {
        self.init(userDefaults: .standard)
    }

    /// Test seam; production uses `.shared`.
    init(userDefaults: UserDefaults, trustPolicy: TransactionTrustPolicy = .verifiedOnly) {
        self.userDefaults = userDefaults
        self.trustPolicy = trustPolicy
    }

    /// Reads the mirrored entitlement without touching StoreKit, for launch-time
    /// gating before the first resolution completes. Missing/invalid → `.unknown`,
    /// which fails closed (no ad requests). UserDefaults is thread-safe, so this
    /// is callable from any context.
    nonisolated static func cachedEntitlementState(userDefaults: UserDefaults = .standard) -> AdFreeEntitlementState {
        guard let raw = userDefaults.string(forKey: cachedEntitlementStateKey),
              let state = AdFreeEntitlementState(rawValue: raw) else {
            return .unknown
        }
        return state
    }

    /// Idempotent launch hook: starts the Transaction.updates listener and
    /// kicks off the initial product load + entitlement resolution.
    func start() {
        guard updatesTask == nil else { return }

        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                // Finish trusted transactions so StoreKit stops redelivering
                // them; never finish untrusted ones.
                if let transaction = self.trusted(update) {
                    await transaction.finish()
                }
                await self.refreshEntitlement()
            }
        }

        // Transaction.updates only fires when a new transaction exists.
        // Grace-period entry, billing-retry entry, auto-renew cancellation,
        // and natural expiry are delivered on the status stream instead.
        statusUpdatesTask = Task { [weak self] in
            for await _ in Product.SubscriptionInfo.Status.updates {
                guard let self else { return }
                await self.refreshEntitlement()
            }
        }

        Task { [weak self] in
            // The storefront can attach a beat after process start (notably
            // under a local StoreKit configuration); querying StoreKit before
            // it does can wedge the whole session's store connection. In
            // production Storefront.current resolves immediately.
            for _ in 0..<50 {
                if await Storefront.current != nil { break }
                try? await Task.sleep(for: .milliseconds(200))
            }
            guard let self else { return }
            // Deliberately parallel: entitlement resolution must never wait
            // on the product catalog (Product.products can stall for minutes
            // on a cold store), and the paywall's products must not wait on
            // entitlement either.
            Task { await self.loadProducts() }
            Task { await self.refreshEntitlement() }
        }
    }

    private var productsLoadInFlight = false

    func loadProducts() async {
        guard !productsLoadInFlight else { return }
        productsLoadInFlight = true
        defer { productsLoadInFlight = false }
        let hadProducts = !products.isEmpty
        do {
            let loaded = try await Product.products(for: ProductID.all)
            products = loaded.sorted { $0.price < $1.price }
            productsLoadFailed = false
        } catch {
            productsLoadFailed = true
            logger.error("Failed to load Ad-Free products: \(error)")
        }

        // Entitlement resolution refines its answer with subscription-group
        // status, which needs a loaded product. currentEntitlements is served
        // from the local cache while Product.products is a network round
        // trip, so the first resolution of a launch almost always runs
        // without status — re-resolve once the catalog lands, or grace-period
        // and billing-retry states would be unreachable until the next
        // foreground.
        if !hadProducts, !products.isEmpty {
            await refreshEntitlement()
        }
    }

    /// Re-derives the entitlement state from StoreKit. Safe to call at any
    /// time; also invoked by the transaction and status listeners. Concurrent
    /// calls are safe: only the newest run commits its result.
    @discardableResult
    func refreshEntitlement() async -> AdFreeEntitlementState {
        refreshGeneration += 1
        let generation = refreshGeneration

        // Retry a failed catalog load in the background — but NEVER await it
        // here: entitlement resolution is the ad/paywall gate and must not
        // serialize behind Product.products, which can stall on a cold store.
        // Without products the status refinement below is skipped and the
        // resolver falls back to currentEntitlements alone (grace period then
        // reads as .active until a later refresh adds status detail).
        if products.isEmpty {
            Task { [weak self] in
                await self?.loadProducts()
            }
        }

        var hasVerifiedEntitlement = false
        var entitledProductID: String?
        var entitledExpiration: Date?

        for await result in Transaction.currentEntitlements {
            guard let transaction = trusted(result),
                  ProductID.all.contains(transaction.productID),
                  transaction.revocationDate == nil else {
                continue
            }
            hasVerifiedEntitlement = true
            entitledProductID = transaction.productID
            entitledExpiration = transaction.expirationDate
        }

        // Subscription-group status distinguishes grace period from billing
        // retry. Status is group-scoped, so any loaded product's subscription
        // works. When it can't be fetched (offline, products not loaded), the
        // resolver falls back to currentEntitlements alone. Only statuses whose
        // backing transaction verifies are trusted.
        var renewalStates: [SubscriptionRenewalStateKind] = []
        var autoRenews: Bool?
        var statusProductID: String?
        var statusExpiration: Date?
        if let subscription = products.compactMap(\.subscription).first,
           let statuses = try? await subscription.status {
            for status in statuses {
                guard let statusTransaction = trusted(status.transaction) else { continue }
                if let kind = Self.renewalStateKind(status.state) {
                    renewalStates.append(kind)
                }
                if let renewalInfo = trusted(status.renewalInfo) {
                    autoRenews = renewalInfo.willAutoRenew
                }
                // The status store can update before currentEntitlements does
                // (e.g. right after a purchase or crossgrade); keep its
                // transaction as a display-info fallback for that window.
                if statusProductID == nil, ProductID.all.contains(statusTransaction.productID) {
                    statusProductID = statusTransaction.productID
                    statusExpiration = statusTransaction.expirationDate
                }
            }
        }

        let resolved = entitlementOverrideForTesting
            ?? AdFreeEntitlementResolver.resolve(
                hasVerifiedEntitlement: hasVerifiedEntitlement,
                renewalStates: renewalStates
            )

        // Overtaken while suspended above — a newer refresh has fresher data,
        // so don't commit. The value is still returned: this run did read
        // post-await entitlements, so it's a correct answer for its own
        // caller (restorePurchases relies on that read-after-write).
        guard generation == refreshGeneration else { return resolved }

        logger.info("Ad-Free entitlement resolved: \(resolved.rawValue, privacy: .public)")
        entitlementState = resolved
        activeProductID = resolved.isAdFree ? (entitledProductID ?? statusProductID) : nil
        expirationDate = resolved.isAdFree ? (entitledExpiration ?? statusExpiration) : nil
        willAutoRenew = resolved.isAdFree ? autoRenews : nil
        userDefaults.set(resolved.rawValue, forKey: Self.cachedEntitlementStateKey)
        return resolved
    }

    @discardableResult
    func purchase(_ product: Product) async throws -> PurchaseOutcome {
        try await handlePurchaseResult(product.purchase())
    }

    /// Shared endpoint for purchase results, whether the purchase ran through
    /// `purchase(_:)` or a StoreKit view (the paywall's SubscriptionStoreView
    /// delivers its result via onInAppPurchaseCompletion).
    @discardableResult
    func handlePurchaseResult(_ result: Product.PurchaseResult) async throws -> PurchaseOutcome {
        switch result {
        case .success(let verification):
            guard let transaction = trusted(verification) else {
                throw StoreError.failedVerification
            }
            await transaction.finish()
            await refreshEntitlement()
            return .success
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    /// Apple-required restore path. AppStore.sync forces a sync with the App
    /// Store (prompts for credentials on a fresh install), then entitlements
    /// are re-derived.
    /// Returns the entitlement this restore itself resolved. Callers must use
    /// the returned value rather than re-reading `entitlementState`: the
    /// sync can make the Transaction.updates listener fire its own refresh,
    /// which would overtake this one and leave the shared property momentarily
    /// behind what the user just restored.
    @discardableResult
    func restorePurchases() async throws -> AdFreeEntitlementState {
        try await AppStore.sync()
        return await refreshEntitlement()
    }

    /// Unwraps a StoreKit verification result according to the trust policy.
    private func trusted<T>(_ result: VerificationResult<T>) -> T? {
        switch result {
        case .verified(let value):
            return value
        case .unverified(let value, let error):
            if trustPolicy == .acceptTestSignatures, case .invalidSignature = error {
                return value
            }
            return nil
        }
    }

    private static func renewalStateKind(
        _ state: Product.SubscriptionInfo.RenewalState
    ) -> SubscriptionRenewalStateKind? {
        switch state {
        case .subscribed: .subscribed
        case .expired: .expired
        case .inBillingRetryPeriod: .inBillingRetryPeriod
        case .inGracePeriod: .inGracePeriod
        case .revoked: .revoked
        default: nil
        }
    }
}
