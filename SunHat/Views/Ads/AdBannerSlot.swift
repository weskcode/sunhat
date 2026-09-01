//
//  AdBannerSlot.swift
//  SunHat
//
//  The complete bottom banner slot for a screen: hairline separator, a quiet
//  "Remove Ads" affordance opening the paywall, and the adaptive banner, on an
//  opaque background so scrolling content reads as clearly distinct from the
//  ad (Google banner policy: visual separation, fixed reserved space, never
//  adjacent to interactive controls without clear spacing).
//
//  Renders nothing at all for Ad-Free users or before entitlement resolves.
//

import SwiftUI

struct AdBannerSlot: View {
    let adUnitID: String

    @State private var adManager = AdManager.shared
    @State private var showingPaywall = false

    var body: some View {
        // The sheet is attached OUTSIDE the entitlement branch on purpose:
        // completing a purchase flips shouldShowAdSlots to false, and a sheet
        // hosted inside that branch would tear down its own presenter
        // mid-flow. A zero-height Color is a stable host and, under
        // safeAreaInset(edge:.bottom), contributes no inset.
        Group {
            if adManager.shouldShowAdSlots {
                VStack(spacing: 0) {
                    Divider()

                    HStack {
                        Spacer()
                        Button {
                            showingPaywall = true
                        } label: {
                            Text("Remove Ads", comment: "Quiet link above the banner ad that opens the Ad-Free paywall")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 5)

                    // Generous gap between the tappable link and the ad itself —
                    // accidental-click adjacency is the top AdMob policy trap.
                    BannerAdView(adUnitID: adUnitID)
                        .padding(.top, 14)
                        .padding(.bottom, 6)
                }
                .background(Color(.systemBackground))
            } else {
                Color.clear.frame(height: 0)
            }
        }
        .sheet(isPresented: $showingPaywall) {
            AdFreePaywallView()
        }
    }
}
