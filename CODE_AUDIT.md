# SunHat Code Audit

Generated 2026-06-27. Scope: 150 Swift files across `SunHat`, `SunHatTests`, and `SunHatUITests`. Existing dirty files outside the test fixes were treated as pre-existing work and were not reverted.

App identity: SunHat is a weather-triggered reminder app. The core flow is create reminder -> monitor weather/location -> evaluate trigger -> notify the user. The visual theme is iOS 26.4 SwiftUI with Liquid Glass card surfaces, semantic system typography, native settings/list patterns, and weather-oriented blue/green status color.

---

## 1. Executive summary

1. **[High] UI tests were not Swift 6.2 actor-isolation clean** - §3.1 - `SunHatUITests/DashboardUITests.swift:15` and `SunHatUITests/SunHatUITests.swift:15`. Fixed by moving XCUI work into main-actor test methods and local app launch helpers.
2. **[Medium] `DetailedReminderViewModel` started an unowned repeating weather timer** - §7.1 - `SunHat/ViewModels/DetailedReminderViewModel.swift:175`. Fixed by owning refresh and prediction timers in an invalidating helper.
3. **[Medium] Unit tests had assertions that could never fail usefully** - §5.1 - `SunHatTests/ReminderCreationTests.swift:441`, `SunHatTests/WeatherServiceTests.swift:41`, `SunHatTests/WeatherServiceTests.swift:209`. Fixed with concrete behavior checks.
4. **[Medium] XCTest execution is currently blocked by simulator runner hangs** - §12.1. `build-for-testing` succeeds, but `test` and `test-without-building` stalled and were stopped.
5. **[Low] App Intents metadata extraction emits bundle warnings** - §4.1. Remaining warnings are from metadata extraction, not Swift source diagnostics.
6. **[High] Physical-device notification-loop verification remains out of scope for this run** - §11.1. The simulator cannot prove background task delivery.

---

## 2. Quick wins

- Fixed UI-test actor-isolation diagnostics in `SunHatUITests/DashboardUITests.swift` and `SunHatUITests/SunHatUITests.swift`.
- Replaced manual main-queue callback hops in UI-facing app code with `Task { @MainActor in ... }`.
- Fixed an unowned repeating weather refresh timer in `DetailedReminderViewModel`.
- Replaced non-optional `nil` checks with assertions that validate configuration, string content, and color tiers.
- Verified `xcodebuild build` and `xcodebuild build-for-testing` after the changes.

---

## 3. Concurrency

### 3.1 UI tests touched XCUIAutomation from non-main-actor contexts
- **Location:** `SunHatUITests/DashboardUITests.swift:15-23`, `SunHatUITests/SunHatUITests.swift:15-19`
- **What:** The UI tests stored one shared `XCUIApplication` from XCTest setup and then accessed XCUIAutomation APIs from test methods.
- **Why:** Under Swift 6.2, XCUIAutomation APIs are main-actor isolated; these warnings will become harder failures as concurrency checking tightens.
- **Action:** Added main-actor local launch helpers and marked UI tests that touch XCUI APIs as `@MainActor`.
- **Severity:** High

### 3.2 UI-facing callbacks used manual main-queue dispatch
- **Location:** `SunHat/Views/Onboarding/NotificationPermissionView.swift:370`, `SunHat/Views/Location/LocationPermissionView.swift:351`, `SunHat/ViewModels/LocationManagementViewModel.swift:405`
- **What:** Completion handlers manually bounced to `DispatchQueue.main.async` before touching SwiftUI or main-actor view-model state.
- **Why:** The project is Swift 6 with main-actor defaults; explicit actor hops are clearer and better aligned with strict concurrency checking than queue-based UI mutation.
- **Action:** Replaced the queue hops with `Task { @MainActor in ... }`.
- **Severity:** Medium

---

## 4. API modernity

### 4.1 App Intents metadata extraction warning remains
- **Location:** build log, `appintentsmetadataprocessor`
- **What:** Build logs warn: metadata extraction skipped because no AppIntents framework dependency was found.
- **Why:** This is not a Swift source warning, but it prevents a truly warning-free build log.
- **Action:** Leave alone unless SunHat is meant to ship App Intents now; otherwise disable that extraction path or add App Intents only with a real shortcut surface.
- **Severity:** Low

---

## 5. Bugs / logic errors

### 5.1 Tests asserted non-optional values were not nil
- **Location:** `SunHatTests/ReminderCreationTests.swift:441-454`, `SunHatTests/WeatherServiceTests.swift:41-48`, `SunHatTests/WeatherServiceTests.swift:209-213`
- **What:** Several tests compared non-optional values to `nil`, so the assertions could not catch regressions.
- **Why:** Passing tests that cannot fail reduce confidence and obscure real behavior gaps.
- **Action:** Replaced them with concrete checks for color tier mapping, configured API key, and non-empty day names.
- **Severity:** Medium

---

## 6. Security

_No new security findings in the files changed during this pass._

---

## 7. Performance

### 7.1 `DetailedReminderViewModel` started an unowned repeating timer
- **Location:** `SunHat/ViewModels/DetailedReminderViewModel.swift:175-184`
- **What:** `setupBindings()` created a repeating 60-second timer without storing it, so it could not be invalidated if the view model went away or bindings were set up again.
- **Why:** Repeating timers can keep firing after their owner is gone, wasting work and obscuring lifecycle bugs.
- **Action:** Added a distinct weather refresh timer alongside the live prediction timer and centralized invalidation in a nonisolated timer holder.
- **Severity:** Medium

### 7.2 UI performance tests still depend on XCTest simulator stability
- **Location:** `SunHatUITests/DashboardUITests.swift:310-360`, `SunHatUITests/SunHatUITests.swift:118-122`
- **What:** Performance tests compile, but they cannot currently execute in this environment because the runner stalls.
- **Why:** Scroll, memory, and launch metrics are only useful when XCTest execution is reliable.
- **Action:** Re-run on a stable simulator/device before using these metrics for performance conclusions.
- **Severity:** Medium

---

## 8. SwiftUI / UI

_No UI source changes were made. Visual validation is blocked because `simctl io screenshot` timed out waiting for screen surfaces after launch._

---

## 9. Dead code / duplication / refactor

_No dead-code deletion was attempted. Existing docs still call out unwired compact/widget surfaces as deferred work._

---

## 10. Cross-cutting recommendations

1. Keep UI tests main-actor local: create the `XCUIApplication` inside a main-actor helper or test method rather than shared mutable XCTest state.
2. Prefer actor-bound callback hops over queue-based UI mutation in Swift 6 code.
3. Store and invalidate every repeating timer; do not rely on weak captures alone for lifecycle cleanup.
4. Prefer behavior assertions over existence assertions when the value is non-optional by type.
5. Separate build verification from simulator execution in reports; this checkout can compile cleanly while XCTest execution still stalls.

---

## 11. What was NOT audited

- Physical-device background notification delivery.
- App Store Connect, WeatherKit entitlement provisioning, and production domain/email checks.
- Full Dynamic Type, VoiceOver, and dark/light visual walkthroughs.
- Deep performance profiling with Instruments.
- Third-party or Apple framework internals.

---

## 12. Verification

### 12.1 Build and test-bundle compilation
- **Build:** `xcodebuild -project SunHat.xcodeproj -scheme SunHat -configuration Debug -destination 'platform=iOS Simulator,id=20465D2E-7941-46FD-BAE2-21335FE5F0B1' -derivedDataPath /tmp/SunHatDerivedData-baseline build` succeeded.
- **Test build:** `xcodebuild ... -derivedDataPath /tmp/SunHatDerivedData-after build-for-testing` succeeded.
- **Warnings after fixes:** App Intents metadata extraction warnings only; 0 Swift source warnings observed in the final `build-for-testing` log.
- **Static checks:** `rg "DispatchQueue\\.main\\.async" SunHat -g '*.swift'` found no remaining app-code matches.
- **Test execution:** full `test`, unit-only `test`, and unit-only `test-without-building` stalled with no test output and were stopped.
- **Launch smoke:** `xcrun simctl launch 20465D2E-7941-46FD-BAE2-21335FE5F0B1 org.wesley.sunhat` succeeded with pid 1288.
- **Visual capture:** `simctl io screenshot` timed out waiting for screen surfaces.
