# iOS version strategy: shipping on 26, preparing for 27

**Status as of September 1, 2026.** iOS 26.6.1 is the current public release;
iOS 27 is in developer beta with a public release expected within weeks.
SunHat ships on iOS 26 and treats iOS 27 as forward-compatibility work.

---

## 1. The decisions

| Decision | Choice | Why |
|---|---|---|
| Minimum iOS (deployment target) | **26.0** | Lowered from 26.5 on Sept 7, 2026 for the App Store 1.0 submission. Nothing in the codebase requires a 26.x point release, the only version gates are `@available(iOS 26, *)` and two `#available(iOS 18.0, *)` checks, and all 25 Liquid Glass call sites are valid from 26.0. Holding at 26.5 excluded every 26.0-26.4 install for no compile-time reason. |
| Build SDK / toolchain | **Release Xcode 26.x (iOS 26 SDK)** | What the App Store actually cares about. Beta Xcode builds are rejected at submission. |
| Branching | **Single `main` line + short-lived `feature/ios27-*` branches** | Avoids the long-lived-divergence failure mode; iOS 27 work here is additive, not a port. |

### Why not a long-lived iOS 27 branch

A parallel OS branch is the right tool when two lines genuinely diverge,
different SDKs, different APIs, different products. That is not this
situation:

- An app built with the **iOS 26 SDK runs on iOS 27**. Forward compatibility
  is the platform norm, not something we port to.
- Our iOS 27 work is *verification plus optional adoption*, and optional
  adoption is expressible in one codebase with `if #available(iOS 27, *)`.
- Every long-lived branch duplicates each bug fix and accrues merge debt.
  With one developer and a submission pending, that cost is not repaid.

**When to revisit:** if we decide to adopt an iOS 27-only API that requires
compiling against the iOS 27 SDK, *then* cut `release/ios27` as a real second
line, after iOS 27 is public, and with a dated note in this file.

---

## 2. Toolchain requirements (submission blocker)

> **Apple rejects App Store builds made with a beta Xcode or beta SDK.**

**RESOLVED Sept 1, 2026.** Release **Xcode 26.6 (17F113)** is installed at
`/Applications/Xcode-26.6.0.app` and selected. Xcode 27 beta remains at
`/Applications/Xcode-beta.app` for iOS 27 work only. Verify with
`xcodebuild -version`; switch with `sudo xcodes select 26.6`.

Release build for a generic iOS device against the iOS 26 SDK is verified
(`BUILD SUCCEEDED`), so the toolchain half of submission readiness is done.

### Toolchain issues and their real causes (updated Sept 1, 2026)

Recorded so they are not re-debugged. Two were previously misattributed to the
iOS 27 beta; both had different real causes.

- **StoreKit-Testing storefront missing in UI tests (FIXED).** Not a beta bug:
  the scheme's `TestAction` was missing its `StoreKitConfigurationFileReference`
  (it was set only on `LaunchAction`). Fixed in 87580fc.
- **`SKTestSession` fails on the iOS 26.x simulator (OPEN: Apple bug).**
  On the iOS 26.5 simulator runtime, every `SKTestSession` instance method
  returns `SKInternalErrorDomain Code=3` ("Error saving configuration file"),
  and `Product.products` returns empty. Cause: `xcodebuild test` from the
  command line does not push the scheme's StoreKit configuration into the
  destination simulator's `storekitd` container, verified here, the device's
  `data/tmp/com.apple.storekit` directory is created but stays empty. This is
  reported by others against iOS 26.3/26.4/26.5 runtimes (see the Flutter
  issue `flutter/flutter#184678` and Apple's developer forums).
  - **Not** caused by our `.storekit` file, our scheme, or stale simulator
    state, verified by removing the TestAction config (still failed) and by
    `simctl erase` (still failed).
  - **Workaround:** open the project in Xcode, Run (Cmd+R) on the target
    simulator, wait ~20–30s, Stop (Cmd+.), then Test (Cmd+U). Running once
    from the IDE seeds `storekitd`, after which command-line runs work for
    that simulator. There is no headless equivalent, `simctl` has no
    `storekit` subcommand.
  - **Scope is the RUNTIME, not the toolchain (proven Sept 1-2).** The same
    Xcode 26.6 build runs all 6 `StoreManagerStoreKitTests` green on the
    **iOS 27.0** simulator, and all 332 unit tests pass there. Only the iOS
    26.5 simulator runtime is affected. So the purchase pipeline IS verified
    on the shipping toolchain, use the iOS 27 sim
    (`1C67F44E-0EFC-46DF-8797-D3AEA5BCAF03`) for StoreKit test runs until
    Apple fixes the 26.x runtime.
  - **Ordering dependency:** `testPurchaseUnlocksAdFreeAndPersists` only gets a
    storefront when the unit tests run FIRST in the same invocation (their
    `SKTestSession` warms `storekitd`). Run it alone and the paywall never
    loads. Giving the UI test its own `SKTestSession` was tried and REVERTED:
    two competing sessions broke 5 unit tests (they slowed from ~0.05s to
    ~5.6s, then failed).
- **Simulator instability / hung `xcodebuild`** on the beta remains real; also
  check `uptime`, since concurrent sessions have driven load average past 1000
  and silently killed test runs.
- **SwiftPM binary artifacts:** truncated XCFramework downloads cached in
  `~/Library/Caches/org.swift.swiftpm/artifacts` poison every later extract
  until the cache is purged.

### Xcode 26.6 migration notes (Sept 1, 2026)

Installed with `xcodes install 26.6` → `/Applications/Xcode-26.6.0.app`,
selected via `sudo xcodes select 26.6`. Steps that were not obvious:

1. `xcodebuild -downloadPlatform iOS` is required after switching: otherwise
   xcodebuild reports "iOS 26.5 is not installed" and offers zero destinations,
   even though `simctl` lists the runtime and the SDK is on disk.
2. That installs runtime build **23F77**, distinct from the **23F73** that
   Xcode 27 beta installed. Both share the identifier
   `com.apple.CoreSimulator.SimRuntime.iOS-26-5`, so `simctl create` can land
   on the wrong one; a device on 23F73 fails asset compilation with
   "No simulator runtime version ... available to use with iphonesimulator SDK
   version 23F81a".
3. The new runtime does not register until Xcode 26.6 is opened once in the GUI.
4. Working simulator: `SunHat-iOS265` =
   `FE834F9C-0251-4AB1-9301-5EEA61AFE809`.

**Verified on Xcode 26.6:** `BUILD SUCCEEDED` for Release / generic iOS device
against the iOS 26 SDK, the actual App Store requirement, plus
`TEST BUILD SUCCEEDED` and 327/332 unit tests passing.

---

## 3. iOS 27 support plan

Work in short-lived `feature/ios27-*` branches off `main`, merged back when
each item is verified. Nothing here should raise the deployment target or
require the iOS 27 SDK.

### Phase A: Compatibility verification (can start now, on the beta)

Run the app on an iOS 27 simulator built with the **iOS 26 SDK**, this is
exactly what a user on iOS 27 will run after installing from the App Store.

- [ ] Full unit + UI suite green on an iOS 27 simulator.
- [ ] Visual pass on every screen: Liquid Glass rendering, tab bar
      minimize-on-scroll, Dynamic Type, light/dark.
- [ ] Weather pipeline: WeatherKit auth and fetches on iOS 27.
- [ ] Background work: `BGAppRefreshTask` / `BGContinuedProcessingTask`
      scheduling and delivery.
- [ ] Notifications: categories, actions, deep links, quiet hours.
- [ ] Monetization: ad slots render and respect entitlement; paywall,
      purchase, restore, and manage-subscription all work.
- [ ] SwiftData: store opens, migrates, and survives relaunch.

### Phase B: Deprecations and behavior changes

- [ ] Build against the iOS 27 SDK **in a scratch branch only** and triage every
      new deprecation warning. Record findings here; do not merge SDK-dependent
      changes into `main`.
- [ ] Review the iOS 27 release notes for behavior changes affecting
      CoreLocation permissions, `BackgroundTasks` budgets, `UNUserNotification`
      presentation, App Tracking Transparency, and StoreKit.
- [ ] Confirm Google Mobile Ads and UMP publish iOS 27-compatible releases;
      bump the SPM pins on a `feature/ios27-sdk-bumps` branch.

### Phase C: Optional adoption (only after iOS 27 is public)

Adopt new APIs only where they earn their place, always behind
`if #available(iOS 27, *)` with the existing iOS 26 path intact.

- [ ] Evaluate new SwiftUI/WidgetKit affordances against the deferred
      widget and watchOS plans.
- [ ] Re-evaluate whether anything justifies moving the deployment target.

### Phase D: Release

- [ ] Ship the iOS 26 build first; do not block submission on iOS 27 work.
- [ ] After iOS 27 is public, run Phase A once more against the release build.
- [ ] Ship an iOS 27-verified update, noting compatibility in the release notes.

---

## 4. Branch and tag conventions

Extends the lightweight Gitflow in `CONTRIBUTING.md`, no `develop`,
no `release`, no `hotfix` branches.

- `main`: always the submission-ready iOS 26 line.
- `feature/*`, `fix/*`: short-lived, merged via PR, deleted after merge.
- `feature/ios27-*`: iOS 27 compatibility work; same lifecycle, merged into
  `main` behind availability guards.
- **Tag the submitted commit** (`v1.0-ios26`) so the exact shipped tree is
  recoverable independent of later iOS 27 changes.
