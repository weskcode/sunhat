//
//  BannerAdView.swift
//  SunHat
//
//  Reusable banner slot using Google's smallest standard unit — the fixed
//  320x50 banner — centered on its own reserved row. Renders nothing at all
//  (zero height, no ad request) unless AdManager.shouldShowAdSlots is true.
//  The 50pt height is reserved up front, so content never shifts when an ad
//  loads or fails — a Google banner-policy requirement. On load failure the
//  reserved space stays blank.
//
//  Presentation mirrors QuoteReaper's AdBannerView: a bare transparent
//  banner (no painted chrome), explicit root view controller, and a static
//  "Advertisement" accessibility element.
//

import SwiftUI
import UIKit
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

    @State private var adManager = AdManager.shared

    var body: some View {
        // shouldShowAdSlots is reactive through both AdManager and
        // StoreManager observation: a purchase mid-session removes the banner
        // immediately.
        if adManager.shouldShowAdSlots {
            SmallBannerRepresentable(adUnitID: adUnitID)
                .frame(width: 320, height: 50)
                .frame(maxWidth: .infinity)
        }
    }
}

private struct SmallBannerRepresentable: UIViewRepresentable {
    let adUnitID: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID
        // QuoteReaper-style presentation: transparent banner on the slot's own
        // background, no painted chrome of its own.
        banner.backgroundColor = .clear
        banner.rootViewController = Self.rootViewController
        banner.isAccessibilityElement = true
        banner.accessibilityLabel = String(
            localized: "Advertisement",
            comment: "Accessibility label for the banner advertisement"
        )
        banner.accessibilityIdentifier = "ad-banner"
        banner.delegate = context.coordinator
        banner.load(Request())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        // The 320x50 size never changes; nothing to update.
    }

    private static var rootViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
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
