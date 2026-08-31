//
//  BannerAdView.swift
//  SunHat
//
//  Reusable adaptive banner slot. Renders nothing at all (zero height, no ad
//  request) unless AdManager.canServeAds is true. When active it reserves the
//  exact adaptive-banner height for the current width up front, so content
//  never shifts when an ad loads or fails — a Google banner-policy
//  requirement. On load failure the reserved space stays blank.
//

import SwiftUI
import GoogleMobileAds

/// Ad unit IDs, one constant per placement — Google's public iOS TEST units.
/// Phase 8 (go-live) replaces each with a real per-placement unit ID from the
/// AdMob console; the only other Google ID in the codebase is the sample
/// GADApplicationIdentifier in Info.plist, which is swapped at the same time.
enum AdConfig {
    static let dashboardBannerUnitID = "ca-app-pub-3940256099942544/2435281174"
    static let weatherBannerUnitID = "ca-app-pub-3940256099942544/2435281174"
}

struct BannerAdView: View {
    let adUnitID: String

    @State private var width: CGFloat = 0
    @State private var adManager = AdManager.shared

    var body: some View {
        // shouldShowAdSlots is reactive through both AdManager and
        // StoreManager observation: a purchase mid-session removes the banner
        // immediately.
        if adManager.shouldShowAdSlots {
            // The 1pt probe (with the banner overlaid on its top edge) must be
            // pinned to the TOP of the reserved frame; the default .center
            // alignment would push the banner half outside the slot.
            Color.clear
                .frame(height: 1)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.width
                } action: { newWidth in
                    width = newWidth
                }
                .overlay(alignment: .top) {
                    if width > 0 {
                        let size = currentOrientationAnchoredAdaptiveBanner(width: width)
                        AdaptiveBannerRepresentable(adUnitID: adUnitID, adSize: size)
                            .frame(width: size.size.width, height: size.size.height)
                    }
                }
                .frame(
                    height: width > 0 ? currentOrientationAnchoredAdaptiveBanner(width: width).size.height : 1,
                    alignment: .top
                )
                // Google's test creatives can render larger than the returned
                // AdSize; never let ad content bleed over app UI or the tab bar.
                .clipped()
        }
    }
}

private struct AdaptiveBannerRepresentable: UIViewRepresentable {
    let adUnitID: String
    let adSize: AdSize

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = adUnitID
        banner.delegate = context.coordinator
        banner.load(Request())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        // Reload only when the adaptive size actually changed (rotation).
        if banner.adSize.size != adSize.size {
            banner.adSize = adSize
            banner.load(Request())
        }
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            bannerView.alpha = 0
            UIView.animate(withDuration: 0.25) {
                bannerView.alpha = 1
            }
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            // Keep the reserved space (no layout shift); stay blank.
            bannerView.alpha = 0
        }
    }
}
