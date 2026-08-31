//
//  AdFreeSettingsSection.swift
//  SunHat
//
//  The "SunHat Ad-Free" section of Settings: current plan, manage/cancel via
//  Apple's manage-subscriptions sheet, and Restore Purchases. The paywall
//  entry point for non-subscribers is added separately.
//

import SwiftUI
import StoreKit

struct AdFreeSettingsSection: View {
    @Environment(StoreManager.self) private var storeManager

    @State private var showingManageSubscriptions = false
    @State private var showingPaywall = false
    @State private var isRestoring = false
    @State private var restoreResult: RestoreResult?

    private enum RestoreResult: Identifiable {
        case restored
        case nothingToRestore
        case billingIssue
        case failed

        var id: Self { self }

        var title: String {
            switch self {
            case .restored:
                String(localized: "Purchases Restored", comment: "Alert title after a successful restore that found an Ad-Free subscription")
            case .nothingToRestore:
                String(localized: "No Purchases Found", comment: "Alert title after a restore that found no Ad-Free subscription")
            case .billingIssue:
                String(localized: "Billing Issue Found", comment: "Alert title after a restore that found a subscription paused by a failed payment")
            case .failed:
                String(localized: "Restore Failed", comment: "Alert title when restoring purchases fails")
            }
        }

        var message: String {
            switch self {
            case .restored:
                String(localized: "Your Ad-Free subscription is back. Ads are now off.", comment: "Alert message after a successful restore")
            case .nothingToRestore:
                String(localized: "No active Ad-Free subscription is associated with your App Store account.", comment: "Alert message when restore finds nothing")
            case .billingIssue:
                String(localized: "Your Ad-Free subscription is paused because a renewal payment failed. Update your billing details to restore it.", comment: "Alert message when restore finds a subscription in billing retry")
            case .failed:
                String(localized: "Could not reach the App Store. Check your connection and try again.", comment: "Alert message when restore fails")
            }
        }
    }

    var body: some View {
        Section {
            switch storeManager.entitlementState {
            case .active:
                currentPlanRow

                // The last paid period's end date. Meaningful only while the
                // subscription is in good standing — in grace period it has
                // already passed, so that branch omits it.
                if let expirationDate = storeManager.expirationDate {
                    LabeledContent(
                        storeManager.willAutoRenew == false
                            ? String(localized: "Expires", comment: "Settings row label when the Ad-Free subscription will not auto-renew")
                            : String(localized: "Renews", comment: "Settings row label for the next Ad-Free renewal date"),
                        value: expirationDate.formatted(date: .abbreviated, time: .omitted)
                    )
                }

                manageSubscriptionButton(title: String(localized: "Manage Subscription", comment: "Settings row that opens Apple's subscription management sheet"))
            case .gracePeriod:
                currentPlanRow
                manageSubscriptionButton(title: String(localized: "Fix Billing Issue", comment: "Settings row that opens subscription management when a renewal payment failed"))
            case .billingRetry:
                manageSubscriptionButton(title: String(localized: "Fix Billing Issue", comment: "Settings row that opens subscription management when a renewal payment failed"))
            case .notEntitled:
                Button {
                    showingPaywall = true
                } label: {
                    SettingsIconLabel(title: String(localized: "Get Ad-Free", comment: "Settings row that opens the Ad-Free subscription paywall"), systemImage: "sparkles", color: .purple)
                }
                .foregroundStyle(.primary)
            case .unknown:
                // Entitlement not resolved yet — don't sell until we know.
                EmptyView()
            }

            restoreButton
        } header: {
            Text("SunHat Ad-Free")
        } footer: {
            Text(footerText)
        }
    }

    private var currentPlanRow: some View {
        LabeledContent {
            Text(storeManager.activePlanDisplayName ?? String(localized: "Ad-Free", comment: "Fallback plan name when the specific Ad-Free plan is unknown"))
        } label: {
            SettingsIconLabel(title: String(localized: "Current Plan", comment: "Settings row showing which Ad-Free plan is active"), systemImage: "sparkles", color: .purple)
        }
    }

    private func manageSubscriptionButton(title: String) -> some View {
        Button {
            showingManageSubscriptions = true
        } label: {
            SettingsIconLabel(title: title, systemImage: "creditcard.fill", color: .blue)
        }
        .foregroundStyle(.primary)
    }

    // The manage sheet and restore alert are attached here because this row
    // exists in every entitlement state: presenting them from a row inside the
    // state switch would tear down the presenting modifier when the sheet's
    // own effect (cancelling, fixing billing) changes the state mid-presentation.
    private var restoreButton: some View {
        Button {
            restorePurchases()
        } label: {
            HStack {
                SettingsIconLabel(title: String(localized: "Restore Purchases", comment: "Settings row that restores a previous Ad-Free purchase"), systemImage: "arrow.clockwise", color: .green)
                if isRestoring {
                    Spacer()
                    ProgressView()
                }
            }
        }
        .foregroundStyle(.primary)
        .disabled(isRestoring)
        .manageSubscriptionsSheet(isPresented: $showingManageSubscriptions)
        .sheet(isPresented: $showingPaywall) {
            AdFreePaywallView()
        }
        .alert(
            restoreResult?.title ?? "",
            isPresented: Binding(
                get: { restoreResult != nil },
                set: { if !$0 { restoreResult = nil } }
            ),
            presenting: restoreResult
        ) { _ in
            Button("OK", role: .cancel) { }
        } message: { result in
            Text(result.message)
        }
    }

    private var footerText: String {
        switch storeManager.entitlementState {
        case .active:
            String(localized: "Ads are off. Cancel anytime — you keep Ad-Free until the end of the period you already paid for.", comment: "Settings footer while the Ad-Free subscription is active")
        case .gracePeriod:
            String(localized: "A renewal payment failed. Ads stay off while Apple retries — update your billing details to keep Ad-Free.", comment: "Settings footer during the billing grace period")
        case .billingRetry:
            String(localized: "Your Ad-Free subscription is paused because a renewal payment failed. Update your billing details to restore it.", comment: "Settings footer during billing retry after the grace period lapsed")
        case .notEntitled, .unknown:
            String(localized: "Remove every ad from SunHat with a monthly or annual plan. Already subscribed on another device or a previous install? Restore Purchases brings Ad-Free back.", comment: "Settings footer shown to non-subscribers")
        }
    }

    private func restorePurchases() {
        isRestoring = true
        Task {
            defer { isRestoring = false }
            do {
                try await storeManager.restorePurchases()
                if storeManager.isAdFree {
                    restoreResult = .restored
                } else if storeManager.entitlementState == .billingRetry {
                    restoreResult = .billingIssue
                } else {
                    restoreResult = .nothingToRestore
                }
            } catch StoreKitError.userCancelled {
                // The user dismissed the App Store sign-in prompt — not a failure.
            } catch {
                restoreResult = .failed
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        Form {
            AdFreeSettingsSection()
        }
    }
    .environment(StoreManager.shared)
}
