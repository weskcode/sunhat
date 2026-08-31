//
//  AdFreePaywallView.swift
//  SunHat
//
//  The "SunHat Ad-Free" paywall — direction A ("System Store", chosen
//  2026-08-30): a custom marketing header on top of Apple's
//  SubscriptionStoreView, which renders the tier picker, localized pricing,
//  auto-renewal disclosure, and buy button itself. Both plans are shown at
//  full price with no pre-selection tricks; Restore and the policy links are
//  system-provided.
//

import SwiftUI
import StoreKit

struct AdFreePaywallView: View {
    @Environment(StoreManager.self) private var storeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SubscriptionStoreView(productIDs: StoreManager.ProductID.all) {
            marketingHeader
                .containerBackground(Color(.systemBackground), for: .subscriptionStore)
        }
        .subscriptionStoreButtonLabel(.multiline)
        .storeButton(.visible, for: .restorePurchases)
        .subscriptionStorePolicyDestination(url: AppSupportLinks.termsOfServiceURL, for: .termsOfService)
        .subscriptionStorePolicyDestination(url: AppSupportLinks.privacyPolicyURL, for: .privacyPolicy)
        .onInAppPurchaseCompletion { _, result in
            guard case .success(let purchaseResult) = result else { return }
            let outcome = try? await storeManager.handlePurchaseResult(purchaseResult)
            if outcome == .success {
                dismiss()
            }
        }
    }

    private var marketingHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 44))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(.top, 8)

            Text("SunHat Ad-Free")
                .font(.title2.bold())

            Text("Removes all ads from SunHat.", comment: "Paywall subtitle")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                benefitRow(
                    systemImage: "rectangle.slash.fill",
                    color: .orange,
                    text: String(localized: "No banner ads, anywhere in the app", comment: "Paywall benefit row")
                )
                benefitRow(
                    systemImage: "cloud.sun.fill",
                    color: .blue,
                    text: String(localized: "Same forecasts, reminders & alerts", comment: "Paywall benefit row")
                )
                benefitRow(
                    systemImage: "heart.fill",
                    color: .green,
                    text: String(localized: "Supports an independent weather app", comment: "Paywall benefit row")
                )
            }
            .padding(.top, 8)
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 16)
    }

    private func benefitRow(systemImage: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(color.gradient, in: .rect(cornerRadius: 6.5, style: .continuous))
            Text(text)
                .font(.subheadline)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Preview

#Preview {
    AdFreePaywallView()
        .environment(StoreManager.shared)
}
