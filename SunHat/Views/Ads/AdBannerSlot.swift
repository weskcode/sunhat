//
//  AdBannerSlot.swift
//  SunHat
//
//  The complete bottom banner slot for a screen: just the compact 320x50
//  banner with a small breathing gap, matching QuoteReaper's minimal
//  presentation — no divider, no "Remove Ads" affordance (the Ad-Free paywall
//  lives in Settings' "SunHat Ad-Free" section). The opaque background keeps
//  scrolling content visually separated from the ad while it scrolls past
//  (Google banner policy).
//
//  Renders nothing at all for Ad-Free users or before entitlement resolves.
//

import SwiftUI

struct AdBannerSlot: View {
    let adUnitID: String

    @State private var adManager = AdManager.shared

    var body: some View {
        // Gated here as well as inside BannerAdView so the slot collapses to
        // a zero-height inset instead of reserving padding for a hidden
        // banner.
        Group {
            if adManager.shouldShowAdSlots {
                BannerAdView(adUnitID: adUnitID)
                    .padding(.top, 6)
                    .padding(.bottom, 2)
                    .background(Color(.systemBackground))
            } else {
                Color.clear.frame(height: 0)
            }
        }
    }
}
