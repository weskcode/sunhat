# SunHat Product, HIG, ASO, and Code Audit

Snapshot: commit `941d71e` on 2026-07-10. SunHat is a privacy-first, location-aware iPhone app whose primary value is notifying people when real weather conditions match an intended activity. Its strongest product identity is not “another forecast”; it is trustworthy weather-triggered reminders presented through an atmospheric iOS 26 interface.

## 1. Executive summary

### 1.1 Inputs and assumptions (Deliverable A)

- **Available:** local repository, current ASO metadata, App Store media folders, source, tests, project settings, and prior audit documents.
- **Not supplied:** App Store Connect analytics, retention funnel, crash telemetry, live listing URL, ratings/reviews, localization targets, physical-device energy traces, or explicit business model.
- **Assumptions:** US English launch, free/no account/no paywall, iPhone-first, iOS 26.4 minimum, Apple WeatherKit primary, privacy is a differentiator, and activation means creating one enabled reminder with location and notification permission.
- **Questions for the next iteration:** What are current product-page impression/conversion rates? Which onboarding step loses users? What percentage creates a reminder? What percentage grants notifications/location? Are any analytics or crash SDKs actually configured? Which countries matter first? Is iPad supported at launch? Is a subscription planned? Are users reporting missed or false alerts? What are median background refresh and delivery delays on device?

### 1.2 Highest-impact action items

1. **[High/P1] Replace synthetic hourly forecast data** — §5.1 — `SunHat/ViewModels/WeatherViewModel.swift:224-247`.
2. **[High/P1] Stop presenting locally invented conditions as official weather alerts** — §5.2 — `SunHat/ViewModels/WeatherViewModel.swift:253-278`.
3. **[High/P1] Make Data & Analytics controls truthful or remove the screen** — §6.1 — `SunHat/Views/Settings/DataAnalyticsView.swift:10-55`.
4. **[High/P1] Preserve precipitation probability and location in prediction evaluation** — §5.3 — `SunHat/Services/Trigger/TriggerEngine+ForecastAnalysis.swift:120-169`.
5. **[High/P1] Evaluate 24/48-hour dry requirements across the requested period** — §5.4 — `SunHat/Services/Trigger/TriggerEngine+ForecastAnalysis.swift:304-328`.
6. **[High/P1] Guard zero temperature tolerance** — §5.5 — `SunHat/Services/Trigger/TriggerEngine+ForecastAnalysis.swift:247-255`.
7. **[High/P1] Resolve Swift 6 actor-isolation warnings in screenshot UI tests** — §3.1 — `SunHatUITests/ScreenshotCaptureUITests.swift:19-107`.
8. **[Medium/P2] Suspend decorative frame loops when scenes are inactive** — §7.1 — `SunHat/Utilities/Theme/SunHatAtmosphereBackground.swift:19-24`.
9. **[Medium/P2] Replace seasonal placeholder temperatures with explicit unavailable states** — §5.6 — `SunHat/ViewModels/WeatherViewModel.swift:280-289,387-424`.
10. **[Medium/P2] Localize all user-facing copy and measurement formatting** — §8.2.

## 2. Quick wins

### 2.1 Remove an unused UI-test local
- **Location:** `SunHatUITests/ScreenshotCaptureUITests.swift:107`
- **What:** `app` is initialized but unused.
- **Why:** It creates compiler noise that hides meaningful warnings.
- **Action:** Remove the local or use it in the intended assertion.
- **Severity:** Low

### 2.2 Rename “weather alerts” unless sourced from WeatherKit alerts
- **Location:** `SunHat/ViewModels/WeatherViewModel.swift:253-278`
- **What:** Threshold-derived notices use official-sounding warning terminology.
- **Why:** “Excessive Heat Warning” implies an authoritative alert.
- **Action:** Until real alerts are integrated, label these “SunHat advisories” and disclose the threshold.
- **Severity:** Medium

### 2.3 Remove unsupported analytics switches
- **Location:** `SunHat/Views/Settings/DataAnalyticsView.swift:13-55`
- **What:** Three toggles reset on every presentation and control no service.
- **Why:** Removing the screen is safer than shipping false controls.
- **Action:** Hide this destination until a persisted, dependency-injected consent service exists.
- **Severity:** High

### 2.4 ASO metadata is within limits
- **Location:** `AppStore/aso_metadata.txt:1-45`
- **What:** Name 25/30, subtitle 29/30, promotional text 168/170, keywords 100/100.
- **Why:** The draft is submission-safe and clearly communicates the core value.
- **Action:** Keep the current title; test a benefit-led screenshot set before changing metadata.
- **Severity:** Low

## 3. Concurrency

### 3.1 Screenshot UI tests violate main-actor isolation
- **Location:** `SunHatUITests/ScreenshotCaptureUITests.swift:19-107`
- **What:** XCTest/XCUIApplication and screenshot APIs are called from nonisolated synchronous helpers, producing dozens of Swift 6 warnings.
- **Why:** These warnings can become errors under stricter language modes and make the screenshot pipeline brittle.
- **Action:** Isolate the test class and XCUI helper methods to `@MainActor`; keep filesystem-only work outside the actor if needed.
- **Severity:** High

### 3.2 App startup service configuration has no readiness boundary
- **Location:** `SunHat/sunhat.swift:148-163`
- **What:** Weather and trigger services configure in an untracked task while the UI can appear immediately.
- **Why:** Early refresh actions can race configuration and produce transient empty/error states.
- **Action:** Model startup readiness explicitly and gate weather-dependent surfaces until configuration completes or fails.
- **Severity:** Medium

### 3.3 Timer-based refresh owners require lifecycle proof
- **Location:** `SunHat/ViewModels/DashboardViewModel.swift:202`, `SunHat/ViewModels/DetailedReminderViewModel.swift:86-188`
- **What:** Repeating timers drive refresh work.
- **Why:** Timers can continue while views are hidden unless invalidation is exhaustive.
- **Action:** Prefer cancellable task loops owned by view/model lifecycle; add deinit/disappear tests.
- **Severity:** Medium

## 4. API modernity

### 4.1 Core app target is warning-free
- **Location:** `SunHat.xcodeproj/project.pbxproj`
- **What:** A clean generic iOS Simulator Debug build succeeded without source warnings.
- **Why:** This is a strong modernization baseline.
- **Action:** Preserve warning-as-signal discipline and add CI build-for-testing.
- **Severity:** Low

### 4.2 App Intents metadata is not produced
- **Location:** `SunHat/AppIntents/SunHatShortcuts.swift:1`
- **What:** Build-for-testing reports that metadata extraction was skipped because no AppIntents framework dependency was found.
- **Why:** Shortcuts/Spotlight exposure may not be discoverable in the shipped binary.
- **Action:** Verify target membership and linked framework, then inspect the built metadata artifact.
- **Severity:** Medium

## 5. Bugs / logic errors

### 5.1 Hourly forecast is synthetic
- **Location:** `SunHat/ViewModels/WeatherViewModel.swift:224-247`
- **What:** The app creates 24 hourly values using a sine wave, repeats the current condition, and derives precipitation from humidity.
- **Why:** Users may make plans from fabricated forecast data; this directly undermines retention and trust.
- **Action:** Extend `WeatherProviding` with real hourly DTOs. Show an unavailable/retry state when the provider lacks hourly data. Never silently synthesize.
- **Severity:** High

### 5.2 Weather alerts are synthetic
- **Location:** `SunHat/ViewModels/WeatherViewModel.swift:253-278`
- **What:** Local thresholds generate “Excessive Heat Warning” and “High UV Index” entries with invented expiration times.
- **Why:** The UI can be mistaken for official severe-weather information.
- **Action:** Map authoritative provider alerts, including source/area/effective/expiry; otherwise present clearly branded SunHat guidance.
- **Severity:** High

### 5.3 Forecast conversion discards real context
- **Location:** `SunHat/Services/Trigger/TriggerEngine+ForecastAnalysis.swift:120-169`
- **What:** Current precipitation probability and coordinates are hard-coded to zero despite receiving a real location and provider data.
- **Why:** Rain/dry/location-sensitive prediction decisions can be wrong and diagnostics become misleading.
- **Action:** Pass `location.coordinate` and the provider’s current precipitation probability through the transfer model; test rainy and non-zero-coordinate fixtures.
- **Severity:** High

### 5.4 Long dry-period requirements inspect only current conditions
- **Location:** `SunHat/Services/Trigger/TriggerEngine+ForecastAnalysis.swift:304-328`
- **What:** 24-hour and 48-hour dry cases return the same result from one current weather sample.
- **Why:** A reminder may fire even when rain exists elsewhere in the required interval.
- **Action:** Evaluate every forecast interval covering the requested duration and require adequate forecast coverage.
- **Severity:** High

### 5.5 Zero tolerance can produce non-finite confidence
- **Location:** `SunHat/Services/Trigger/TriggerEngine+ForecastAnalysis.swift:247-255`
- **What:** Equality confidence divides by `temperatureTolerance` without clamping it above zero.
- **Why:** Exact matches at zero tolerance can yield NaN, contaminating aggregate confidence and UI formatting.
- **Action:** Validate model invariants and divide by `max(tolerance, epsilon)` or define exact-match confidence explicitly.
- **Severity:** High

### 5.6 Historical and seasonal comparisons silently fall back to placeholders
- **Location:** `SunHat/ViewModels/WeatherViewModel.swift:280-289,387-424`
- **What:** Missing history becomes current temperature; seasonal averages are fixed Fahrenheit-like constants independent of location/unit.
- **Why:** Comparisons can look authoritative while being unrelated to the user’s climate or selected units.
- **Action:** Make comparison values optional with “Not enough history”; compute climatology from real stored/provider data and format through the user’s unit.
- **Severity:** Medium

### 5.7 Store recovery can silently become temporary
- **Location:** `SunHat/sunhat.swift:64-86,179-207`
- **What:** After two store failures, the app uses an in-memory container while remaining interactive.
- **Why:** Changes made in recovery mode disappear after relaunch.
- **Action:** Disable destructive/persistent actions in temporary mode and offer export/contact/retry guidance before accepting edits.
- **Severity:** High

## 6. Security

### 6.1 Privacy controls do not control data collection
- **Location:** `SunHat/Views/Settings/DataAnalyticsView.swift:10-55`
- **What:** Consent-looking toggles are local view state with no persistence or analytics integration.
- **Why:** The UI makes privacy promises it cannot enforce and defaults “Crash Reports” on each presentation.
- **Action:** Remove the controls or back them with a persisted consent repository that gates every telemetry sink; update the privacy manifest and listing together.
- **Severity:** High

### 6.2 Privacy copy requires a source-of-truth review
- **Location:** `SunHat/Views/Settings/DataAnalyticsView.swift:58-69`, `AppStore/aso_metadata.txt:74-78`
- **What:** The app claims not to collect precise location and not to collect analytics while also offering collection toggles and using weather providers.
- **Why:** “Collect,” “store,” and “transmit to a provider” are materially different and must be described precisely.
- **Action:** Inventory every network request, OS diagnostic path, and stored field; align in-app copy, PrivacyInfo.xcprivacy, and App Store privacy answers.
- **Severity:** High

## 7. Performance

### 7.1 Full-screen atmosphere redraws continuously
- **Location:** `SunHat/Utilities/Theme/SunHatAtmosphereBackground.swift:19-24,57-77`
- **What:** A full-screen Canvas redraws at 30 FPS even for subtle, slow background motion.
- **Why:** This can raise GPU/CPU use and battery drain on the app’s main surfaces.
- **Action:** Pause when scene phase is inactive, lower cadence adaptively, cache static layers, and profile Energy Log plus Core Animation on an older supported device.
- **Severity:** Medium

### 7.2 Multiple independent timeline renderers can stack
- **Location:** `SunHat/Utilities/Motion/SunHatMotion.swift:32-44`, `SunHat/Views/Components/WelcomeViewComponents.swift:95-116`, `SunHat/Views/Onboarding/CelebrationView.swift:221-235`
- **What:** Weather, particle, confetti, and atmosphere views own separate TimelineViews.
- **Why:** Concurrent frame loops multiply rendering work during transitions.
- **Action:** Ensure only visible layers animate, consolidate clocks where layers coexist, and set a 60 FPS frame-time target with zero sustained hitches above 33 ms.
- **Severity:** Medium

### 7.3 No Metal shaders exist in the tracked source
- **Location:** `SunHat/Utilities/Theme/SunHatAtmosphereBackground.swift:19-24`
- **What:** The repository contains zero `.metal` files and no SwiftUI shader modifiers; visual effects use Canvas.
- **Why:** A Metal optimization plan cannot be grounded in absent code.
- **Action:** Treat Canvas as the current renderer. If shaders are planned, add them only after measuring a bottleneck; require bounded uniforms, Reduce Motion fallback, representative-content tests, and GPU trace evidence.
- **Severity:** Low

## 8. SwiftUI / UI

### 8.1 Onboarding should deliver value before decoration (Deliverable D)
- **Location:** `SunHat/Views/Onboarding/WelcomeView.swift:11-346`, `SunHat/Views/Onboarding/NotificationPermissionView.swift:19-324`
- **What:** Onboarding has extensive staged animation and explanatory screens before the first durable reminder.
- **Why:** Time-to-first-value is the most important activation lever.
- **Action:** Use three outcomes: one-sentence promise, create a useful reminder from templates, then request location/notifications contextually. Let users skip and use manual city mode.
- **Severity:** Medium

### 8.2 Localization is not production-ready
- **Location:** `SunHat/Views/Settings/DataAnalyticsView.swift:22-76`, `SunHat/Services/Trigger/TriggerEngine+ForecastAnalysis.swift:93-97,235-255`
- **What:** User-facing copy, interpolated sentences, units, and trigger explanations are hard-coded English.
- **Why:** Strings cannot be safely translated, pluralized, reordered, or formatted per locale.
- **Action:** Move copy to String Catalogs, use localized format styles and measurement APIs, and pseudo-localize with 30–40% expansion and RTL testing.
- **Severity:** Medium

### 8.3 Settings information architecture is mostly native and sound
- **Location:** `SunHat/Views/Settings/SettingsView.swift:1-275`
- **What:** Form sections, pickers, destructive reset, and system navigation follow HIG.
- **Why:** This should be preserved while removing nonfunctional/privacy-ambiguous destinations.
- **Action:** Group notification authority/status together, show consequences inline, keep advanced provider/data options behind disclosure, and remove controls that do not persist.
- **Severity:** Low

### 8.4 Repeating preview pulse needs explicit lifecycle stop
- **Location:** `SunHat/Views/Reminders/Creation/ReminderPreviewCards.swift:11-49`
- **What:** Two repeat-forever animations are attached to preview indicators.
- **Why:** They can continue consuming frames and distract from form completion.
- **Action:** Start only when visible and active; use a static semantic status under Reduce Motion and Low Power Mode.
- **Severity:** Medium

### 8.5 Award-winning polish should reinforce trust (Deliverable H)
- **Location:** `SunHat/Views/Dashboard/DashboardView.swift:1`, `SunHat/Views/Components/NextReadyReminderCompactView.swift:1`
- **What:** The differentiated compact “next ready reminder” model exists, but explainability should become the visual centerpiece.
- **Why:** Premium polish here means instantly answering “what will happen, where, when, and why,” not adding more effects.
- **Action:** Add a compact confidence/last-checked/source line, a one-tap “why not yet?” explanation, subtle success haptic after save, and matched transitions only where continuity aids comprehension.
- **Severity:** Medium

## 9. Dead code / duplication / refactor

### 9.1 Large files hide product-state boundaries
- **Location:** `SunHat/ViewModels/FirstReminderCreationViewModel.swift:1-830`, `SunHat/Services/Data/WeatherModelActor.swift:1-777`, `SunHat/Views/Settings/DataPrivacyView.swift:1-711`
- **What:** Several central files exceed 700 lines and mix orchestration, formatting, persistence, and presentation state.
- **Why:** High-change product surfaces become harder to test and review.
- **Action:** Extract behavior by responsibility only when covered by tests: draft validation, provider mapping, export policy, and presentation models are natural seams.
- **Severity:** Medium

### 9.2 Duplicate animation vocabularies remain
- **Location:** `SunHat/Views/Onboarding/WelcomeView.swift:68-346`, `SunHat/Views/Onboarding/NotificationPermissionView.swift:91-324`, `SunHat/Utilities/Motion/SunHatMotion.swift:10-29`
- **What:** Onboarding still embeds many raw curves/delays beside centralized motion tokens.
- **Why:** Timing drifts and Reduce Motion behavior becomes inconsistent.
- **Action:** Finish migration to semantic `SunHatMotion` tokens and test both motion modes.
- **Severity:** Medium

## 10. Cross-cutting recommendations

### 10.1 ASO audit and before/after listing (Deliverable B)

**Current recommended listing (already optimized):**

- Name: `SunHat: Weather Reminders` (25/30)
- Subtitle: `Temperature & Forecast Alerts` (29/30)
- Keywords: `outdoor,notifications,location,conditions,trigger,tracker,planner,smart,rain,sunny,wind,monitor,heat` (100/100)
- Promotional text: current 168-character draft is compliant.

**Before vs after:** retain the metadata as the “after” draft until impression/ranking data proves a need to change it. The larger conversion opportunity is creative truthfulness: screenshot 1 should show the core outcome (“Know when conditions are right”), screenshot 2 a completed reminder with its next likely trigger, screenshot 3 the 20-second creation flow, screenshot 4 “why not yet,” screenshot 5 notification controls, and screenshot 6 privacy/manual location. Avoid claims such as “Always Monitoring” unless physical-device background delivery evidence supports them.

**Icon:** preserve a single bold sun/hat silhouette, high contrast, no text, and validate at 29–60 pt plus dark/tinted appearances.

**Rating strategy:** use the existing lifecycle coordinator only after a successfully delivered/acted-on reminder or several successful creations; never during onboarding or after errors. A user-tapped “Rate SunHat” row should deep-link to the review page rather than attempt to force the system prompt.

**PPO test:** test one variable at a time for at least 2–4 weeks: outcome-led hero versus feature-led hero. Primary metric is first-time download conversion; guardrails are onboarding completion, first-reminder creation, notification opt-in, and week-one retained users. Do not interpret download uplift without activation.

### 10.2 Ordered implementation backlog (Deliverable F)

1. P1 / 2–4 days: real hourly provider contract and unavailable states (`WeatherProviding`, `WeatherService`, `WeatherViewModel`, forecast UI, fixtures/tests).
2. P1 / 1–2 days: authoritative-versus-SunHat advisory model (`WeatherAlert`, provider mapping, alerts UI, copy/tests).
3. P1 / 1 day: fix forecast transfer context and dry-period evaluation (`TriggerEngine+ForecastAnalysis`, DTOs, trigger tests).
4. P1 / 0.5 day: zero-tolerance invariant and regression tests.
5. P1 / 0.5–2 days: remove analytics screen or implement persisted consent repository and privacy-manifest alignment.
6. P1 / 1 day: recovery-mode write gating and user recovery actions.
7. P1 / 0.5 day: annotate screenshot UI tests with `@MainActor` and clear warnings.
8. P2 / 2–4 days: template-first onboarding with permission requests after intent creation.
9. P2 / 2–3 days: scene-aware unified animation clocks and on-device energy profiling.
10. P2 / 3–5 days: String Catalog extraction, measurement formatting, pseudo-localization/RTL pass.

Accessibility applies to every item: preserve semantic controls, 44-point targets, VoiceOver announcements for async state, Dynamic Type without truncation, non-color status, Reduce Motion, and Reduce Transparency. Localization applies to every new string and formatted value.

### 10.3 Verification and release plan (Deliverable G)

- Unit: provider-to-hourly mapping, missing-hourly state, authoritative advisory mapping, precipitation/coordinate preservation, 24/48-hour coverage, zero tolerance, recovery-mode write policy, and consent persistence.
- UI: fresh install → template reminder → manual/current location → notification rationale → save → dashboard explanation; denied permission recovery; offline/cache; empty/error/retry; settings reset; data export/share.
- Accessibility: VoiceOver order, Dynamic Type XXXL, Bold Text, Button Shapes, Differentiate Without Color, Reduce Motion, Reduce Transparency, Increased Contrast, and automated audit.
- Performance targets: p95 launch-to-interactive under 1.5 s on supported reference hardware; scrolling and transitions sustain 60 FPS with p95 frame under 16.7 ms; no repeated >33 ms hitches; no memory growth after ten navigation cycles; background renderer stops when inactive.
- Release: generic simulator build, unit tests, targeted UI tests, physical-device notification/location/background checks, Release archive/export, exported IPA entitlements/privacy manifest/Info.plist inspection, then App Store screenshots and claims checked against the shipped build.

## 11. What was NOT audited

- Live App Store Connect listing, search ranks, competitor metadata, ratings/reviews, product-page analytics, retention, or crash dashboards.
- Physical-device background delivery reliability, WeatherKit quota behavior, energy usage, network conditions, notification timing, and location accuracy.
- Runtime UI screenshots and pixel-level inspection; workspace files were iCloud placeholders, so source/build evidence came from a clean remote clone of the exact current commit.
- Deep algorithmic validation of seasonal/pattern trigger math, CloudKit (disabled), server-side systems, or third-party provider terms.
- Metal kernel correctness, because no Metal source or shader integration exists in the tracked revision.
- Full test execution; build-for-testing succeeded, but tests were not run on a simulator in this pass.

## 12. Verification

- **§3.1** — build-for-testing succeeded and emitted actor-isolation warnings at `SunHatUITests/ScreenshotCaptureUITests.swift:19-107`.
- **§5.1** — `loadHourly()` constructs each hour from `sin(...)` and current values at `SunHat/ViewModels/WeatherViewModel.swift:230-246`.
- **§5.2** — locally created warnings and expirations are visible at `SunHat/ViewModels/WeatherViewModel.swift:253-277`.
- **§5.3** — precipitation probability and latitude/longitude are hard-coded at `SunHat/Services/Trigger/TriggerEngine+ForecastAnalysis.swift:143-153`.
- **§5.4** — both long dry-period cases use one `isWet` value at `SunHat/Services/Trigger/TriggerEngine+ForecastAnalysis.swift:304-328`.
- **§5.5** — tolerance is a direct divisor at `SunHat/Services/Trigger/TriggerEngine+ForecastAnalysis.swift:247-255`.
- **§5.7** — persistent recovery falls back to an in-memory container at `SunHat/sunhat.swift:64-86`.
- **§6.1** — privacy toggles are local `@State` only at `SunHat/Views/Settings/DataAnalyticsView.swift:10-55`.
- **§7.1** — full-screen Canvas is clocked at 30 FPS at `SunHat/Utilities/Theme/SunHatAtmosphereBackground.swift:19-24`.

Build evidence: `xcodebuild ... Debug ... build` succeeded with no app-source warnings. `xcodebuild ... build-for-testing` succeeded; warnings were confined to `ScreenshotCaptureUITests.swift` plus an App Intents metadata warning.

---

## 13. Resolution log — July 19, 2026

All P1 items and most P2 items from §1.2 were implemented and verified (build clean, 242 unit tests / 49 suites passing). Remaining open work is tracked in [TODO.md](TODO.md).

| Item | Status |
|---|---|
| §5.1 Synthetic hourly forecast | **Fixed** — real WeatherKit hours via new `HourlyForecastDTO` pipeline (`WeatherAPI` → `WeatherServiceActor` in-memory cache → `WeatherProviding.fetchHourlyForecast` → `WeatherViewModel.loadHourly`); empty = explicit unavailable state, never synthesized. Tested. |
| §5.2 Synthetic weather alerts | **Fixed** — all threshold notices renamed "SunHat … Advisory" with the threshold disclosed, in `WeatherViewModel`, `DashboardViewModel`, and both UI headers. Tested (no "Warning" titles, `.advisory` severity). |
| §5.3 Forecast conversion discards context | **Fixed** — `evaluateForecastPrediction` passes real coordinates and current precipitation probability (provider hourly first, then today's daily). |
| §5.4 Dry-period single-sample evaluation | **Fixed** — `evaluateDryPeriod` checks every forecast day covering the 24/48-h window and requires full coverage; also applied per-day with the day as reference date. Tested (rain-later fails, dry window passes, no coverage fails). |
| §5.5 Zero-tolerance NaN | **Fixed** — exact match at zero tolerance is confidence 1.0; divisor clamped. Tested. |
| §5.6 Placeholder historical/seasonal values | **Fixed** — comparisons are optional; seasonal constants deleted; monthly average computed from stored data (≥3 samples) or "Not enough history yet" in the UI. Tested. |
| §5.7 Silent temporary recovery mode | **Mitigated** — the existing recovery banner now states that changes will not persist and gives the support contact. Full write-gating remains in TODO. |
| §6.1 / §2.3 Fake analytics controls | **Fixed** — `DataAnalyticsView` was unreachable dead code; deleted. |
| §3.1 / §2.1 UI-test actor isolation | **Fixed** — `ScreenshotCaptureUITests` is `@MainActor`; stale unused-local finding no longer applies to the current file. |
| §7.1 Atmosphere Canvas 30 FPS loop | **Fixed** — `TimelineView` clock pauses when `scenePhase != .active`. |
| §8.2 / §10 Localization, onboarding funnel, ASO experiments | **Open** — tracked in TODO.md (post-launch). |
| (New, found this pass) Privacy delete-all left orphans | **Fixed** — `deleteAllUserData` now explicitly deletes `TriggerCondition` and `ForecastDay`; schema-parity test passes. |
