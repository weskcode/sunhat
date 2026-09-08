//
//  StoreManagerStoreKitTests.swift
//  SunHatTests
//
//  End-to-end StoreKit 2 coverage against the repo's SunHat.storekit
//  configuration via SKTestSession: the config parses and exposes both
//  Ad-Free products, purchases of either tier produce the active entitlement,
//  expiration drops it, and the UserDefaults mirror tracks each resolution.
//  SKTestSession mutates process-global StoreKit state, so the suite is
//  serialized and every test builds a fresh session + StoreManager.
//

import Foundation
import StoreKit
import StoreKitTest
import Testing
@testable import SunHat

@MainActor
// .timeLimit caps the damage when SKTestSession wedges. It has done that
// on this machine: the suite hung and burned a 40-minute run budget while
// every other suite sat waiting behind .serialized. A hang now fails this
// suite in two minutes and lets the rest of the run finish, which is the
// difference between one red suite and no results at all.
@Suite(.serialized, .timeLimit(.minutes(2)))
struct StoreManagerStoreKitTests {

    private static let defaultsSuiteName = "StoreManagerStoreKitTests"

    // #filePath bakes the builder's checkout path into the binary, so this
    // only resolves when tests run on the machine that built them — true for
    // this project's local xcodebuild flow. If a build/test split or path
    // remapping is ever introduced, bundle the .storekit into SunHatTests
    // and load it via Bundle instead.
    private static var configurationURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // SunHatTests/
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("SunHat.storekit")
    }

    private func makeSession() throws -> SKTestSession {
        let session = try SKTestSession(contentsOf: Self.configurationURL)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        // SunHat.storekit sets _billingGracePeriodEnabled, and
        // resetToDefaultState() restores it. That makes expireSubscription
        // ambiguous: the subscription may enter a grace period instead of
        // lapsing, and grace keeps the transaction in currentEntitlements with
        // its ORIGINAL expiration date — so the manager correctly stays
        // ad-free and the lapse assertions fail nondeterministically. These
        // tests cover clean purchase/lapse transitions; grace-period and
        // billing-retry mapping is covered directly against the resolver in
        // AdFreeEntitlementResolverTests.
        session.billingGracePeriodIsEnabled = false
        session.shouldEnterBillingRetryOnRenewal = false
        return session
    }

    private func makeManager() -> (StoreManager, UserDefaults) {
        let defaults = UserDefaults(suiteName: Self.defaultsSuiteName)!
        defaults.removePersistentDomain(forName: Self.defaultsSuiteName)
        // .acceptTestSignatures: SKTestSession transactions are signed with a
        // local test certificate this process doesn't trust, so they arrive
        // as .unverified(_, .invalidSignature). Production uses .verifiedOnly.
        let manager = StoreManager(userDefaults: defaults, trustPolicy: .acceptTestSignatures)
        return (manager, defaults)
    }

    /// StoreKit test-session mutations propagate asynchronously, so poll the
    /// manager instead of assuming one refresh is enough (same pattern as
    /// waitUntilLevelSettles in StoreRecoveryWriteGatingTests).
    private func refreshUntil(
        _ manager: StoreManager,
        reaches expected: AdFreeEntitlementState,
        within timeout: Duration = .seconds(20)
    ) async {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        repeat {
            await manager.refreshEntitlement()
            if manager.entitlementState == expected { return }
            try? await Task.sleep(for: .milliseconds(100))
        } while ContinuousClock.now < deadline
    }

    @Test("The .storekit configuration parses and exposes both Ad-Free products")
    func configurationLoadsBothProducts() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let (manager, _) = makeManager()

        await manager.loadProducts()

        #expect(!manager.productsLoadFailed)
        #expect(manager.products.count == 2)
        #expect(Set(manager.products.map(\.id)) == Set(StoreManager.ProductID.all))

        // Sorted by price: monthly ($1) before yearly ($10).
        #expect(manager.products.first?.id == StoreManager.ProductID.monthly)
        let monthly = try #require(manager.products.first { $0.id == StoreManager.ProductID.monthly })
        let yearly = try #require(manager.products.first { $0.id == StoreManager.ProductID.yearly })
        #expect(monthly.price == 1.00)
        #expect(yearly.price == 10.00)
        #expect(monthly.subscription?.subscriptionGroupID == yearly.subscription?.subscriptionGroupID)
        // The annual tier carries the better-value framing in its own card.
        #expect(yearly.description.localizedCaseInsensitiveContains("two months free"))
    }

    @Test("Fresh install with no purchases resolves to notEntitled and allows ads")
    func noPurchasesResolvesNotEntitled() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let (manager, defaults) = makeManager()

        #expect(manager.entitlementState == .unknown)
        #expect(!manager.allowsAdRequests)

        await manager.loadProducts()
        await refreshUntil(manager, reaches: .notEntitled)

        #expect(manager.entitlementState == .notEntitled)
        #expect(!manager.isAdFree)
        #expect(manager.allowsAdRequests)
        #expect(defaults.string(forKey: StoreManager.cachedEntitlementStateKey) == AdFreeEntitlementState.notEntitled.rawValue)
    }

    @Test("Buying the monthly plan turns Ad-Free on and mirrors the cache")
    func monthlyPurchaseUnlocksAdFree() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let (manager, defaults) = makeManager()
        await manager.loadProducts()

        _ = try await session.buyProduct(identifier: StoreManager.ProductID.monthly)
        await refreshUntil(manager, reaches: .active)

        #expect(manager.entitlementState == .active)
        #expect(manager.isAdFree)
        #expect(!manager.allowsAdRequests)
        #expect(manager.activeProductID == StoreManager.ProductID.monthly)
        #expect(manager.activePlanDisplayName != nil)
        #expect(manager.expirationDate != nil)
        #expect(defaults.string(forKey: StoreManager.cachedEntitlementStateKey) == AdFreeEntitlementState.active.rawValue)
    }

    @Test("Buying the annual plan unlocks the same entitlement")
    func yearlyPurchaseUnlocksAdFree() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let (manager, _) = makeManager()
        await manager.loadProducts()

        _ = try await session.buyProduct(identifier: StoreManager.ProductID.yearly)
        await refreshUntil(manager, reaches: .active)

        #expect(manager.entitlementState == .active)
        #expect(manager.isAdFree)
        #expect(manager.activeProductID == StoreManager.ProductID.yearly)
    }

    @Test("StoreManager.purchase() runs the full verify-finish-refresh path")
    func purchaseThroughStoreManager() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let (manager, _) = makeManager()
        await manager.loadProducts()

        let monthly = try #require(manager.products.first { $0.id == StoreManager.ProductID.monthly })
        let outcome = try await manager.purchase(monthly)

        #expect(outcome == .success)
        #expect(manager.entitlementState == .active)
        #expect(manager.isAdFree)
        #expect(manager.activeProductID == StoreManager.ProductID.monthly)
    }

    @Test("An expired subscription drops back to notEntitled and re-allows ads")
    func expirationDropsEntitlement() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let (manager, defaults) = makeManager()
        await manager.loadProducts()

        let transaction = try await session.buyProduct(identifier: StoreManager.ProductID.monthly)
        await refreshUntil(manager, reaches: .active)
        #expect(manager.isAdFree)

        // Without this, expireSubscription triggers an immediate auto-renewal
        // (new transaction, new expiry) instead of a lapse.
        try session.disableAutoRenewForTransaction(identifier: UInt(transaction.id))
        try session.expireSubscription(productIdentifier: StoreManager.ProductID.monthly)
        await refreshUntil(manager, reaches: .notEntitled)

        #expect(manager.entitlementState == .notEntitled)
        #expect(!manager.isAdFree)
        #expect(manager.allowsAdRequests)
        #expect(manager.activeProductID == nil)
        #expect(manager.expirationDate == nil)
        #expect(defaults.string(forKey: StoreManager.cachedEntitlementStateKey) == AdFreeEntitlementState.notEntitled.rawValue)
    }
}
