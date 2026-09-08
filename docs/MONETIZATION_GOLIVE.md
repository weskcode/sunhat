# Monetization go-live handoff

Everything in the app currently runs on **test/sandbox values**, Google's public
test ad IDs and a local StoreKit configuration, so the whole pipeline (ads
show → purchase → ads gone → restore) is verifiable without any live accounts.
This document lists exactly what to create and where each real value goes.
Written 2026-08-31 at the end of the ads + Ad-Free subscription build
(branch `feature/ads-and-iap`).

## 1. AdMob console: create, then paste

Create at https://apps.admob.com:

| Create | Replaces | Goes in |
|---|---|---|
| iOS app → **App ID** (`ca-app-pub-XXXX~YYYY`) | `ca-app-pub-3940256099942544~1458002511` | `SunHat/Info.plist` → `GADApplicationIdentifier` |
| Banner ad unit "Dashboard Banner" | `ca-app-pub-3940256099942544/2435281174` | `SunHat/Views/Ads/BannerAdView.swift` → `AdConfig.dashboardBannerUnitID` |
| Banner ad unit "Weather Banner" | `ca-app-pub-3940256099942544/2435281174` | `SunHat/Views/Ads/BannerAdView.swift` → `AdConfig.weatherBannerUnitID` |

Those are the only three Google IDs in the codebase (grep `3940256099942544`
to verify nothing is missed).

Also in AdMob → **Privacy & messaging**: publish a **GDPR (European
regulations) message** and an **ATT message is optional**. The app already
integrates the UMP SDK (`AdManager.gatherConsentIfNeeded()`), but the consent
form only serves once a message is published in the console. Without it,
EEA/UK users get no ads (the app fails safe via `canRequestAds`).

Note: new AdMob apps serve limited ads until Google's app review completes,
blank banners in the first days after go-live are expected, not a bug.

## 2. App Store Connect: subscriptions

The product IDs are already final in code and in `SunHat.storekit`; create
them **verbatim**:

- Subscription group: **SunHat Ad-Free**
  - `org.wesley.sunhat.adfree.monthly`: "Ad-Free Monthly", $0.99–$1.00/month
    price point, description: *Removes all ads from SunHat.*
  - `org.wesley.sunhat.adfree.yearly`: "Ad-Free Annual", $9.99–$10.00/year
    price point, description: *Best value, two months free vs. monthly.*
  - **Both at the same group level (rank 1)** so switching plans is a
    crossgrade, matching the local config.
- Sign the **Paid Applications agreement** and set up banking/tax first.
- No code changes needed at this step: `StoreManager.ProductID` already uses
  these IDs; the `.storekit` file stays in the repo for local testing.
- Review notes suggestion: "Free app with banner ads; the auto-renewable
  'SunHat Ad-Free' subscription (monthly/annual, same entitlement) removes
  them. Restore Purchases is in Settings → SunHat Ad-Free. ATT is requested
  from the second session for ad personalization only."

## 2a. Subscription metadata in App Store Connect (required before review)

Creating the product IDs is not enough, App Store Connect will not let the
subscription go to review until each of these exists:

- **Subscription group display name** (user-visible; "SunHat Ad-Free").
- **Per-product localized display name and description** for every locale you
  ship (SunHat ships **en** and **es**, both are required, or review will
  flag the missing localization).
- **Price** for each product in every storefront (set the base tier; App Store
  Connect generates the rest).
- **Subscription duration**: 1 month / 1 year, matching `SunHat.storekit`.
- **A review screenshot of the paywall** for each subscription: Apple
  requires one per product. Capture from `PaywallScreenshotTests`
  (`/tmp/sunhat-shots/paywall-*.png`).
- **Terms of Use (EULA) and Privacy Policy URLs** on the app record. Apple
  requires functional links for auto-renewable subscriptions; the app already
  points at `https://sunhat.apphq.online/terms` and `/privacy`, and both pages must
  describe the subscription (see §4).

## 3. Privacy nutrition labels (App Store Connect)

> **Blocker: `NSPrivacyTrackingDomains` is empty.** Verified that
> GoogleMobileAds 12.14.0 and UserMessagingPlatform 3.1.0 declare neither
> `NSPrivacyTracking` nor `NSPrivacyTrackingDomains` in their bundled
> manifests, so `SunHat/PrivacyInfo.xcprivacy` is the app's only tracking
> declaration. Apple expects a non-empty domain list whenever
> `NSPrivacyTracking` is `true`. Populate it from Google's current published
> list at <https://developers.google.com/admob/ios/privacy> before submitting,
> the values change, so read them at go-live rather than reusing an old list.

With AdMob + ATT, the previous "no tracking" posture changes. Declare:

- **Data Used to Track You**: Device ID (advertising identifier), Advertising
  Data, collected by Google Mobile Ads.
- **Data Not Linked to You**: Precise Location, Coarse Location (app
  functionality, weather; unchanged), plus Google's ad-performance data per
  https://support.google.com/admob/answer/10787689 (Google's own label
  guidance for AdMob publishers).
- The app-level privacy manifest (`SunHat/PrivacyInfo.xcprivacy`) now sets
  `NSPrivacyTracking = true`; Google's SDK ships its own manifest declaring
  its domains/data, and Xcode aggregates both into the privacy report.

## 4. Hosted legal pages

The in-app Privacy Policy (`PrivacyPolicyView`) now discloses AdMob ads, ATT,
and the Ad-Free subscription. The hosted pages must be brought in line before
submission:

- https://sunhat.apphq.online/privacy: add the same Advertising section.
- https://sunhat.apphq.online/terms: add auto-renewable subscription terms (price,
  period, renewal, cancellation via Apple Account settings).

## 5. Switching the app itself to live values

1. Paste the three AdMob IDs (table above).
2. Nothing else changes: the entitlement pipeline, paywall, and consent flow
   are identical against live App Store / live AdMob.
3. Run the integration checks once against TestFlight/sandbox: ads visible →
   purchase either tier → ads gone immediately → relaunch still ad-free →
   Restore Purchases on a re-install.

## What stays test-only (deliberately)

- `SunHat.storekit` + the scheme's StoreKit configuration: local purchase
  testing forever; ignored by App Store builds.
- `SunHatUITests/AdFreeIntegrationUITests.swift`: automated end-to-end loop
  against the local store (purchases persist in the simulator's StoreKit test
  store; reset with `xcrun simctl uninstall <udid> org.wesley.sunhat`).
