# SunHat HIG, Design, and Performance Audit Plan

## Current Verification

- Compile: `build_sim` passes on iPhone 17 Pro, iOS 26.5, with zero diagnostics.
- Launch: app installs and launches as `org.wesley.sunhat` on the same simulator.
- XCTest: blocked by simulator/XCTest launch instability. The MCP test command timed out at 120 seconds; the escalated `xcodebuild -only-testing:SunHatTests test` built successfully but stalled during XCTest launch and was stopped after simulator launch failed.
- First screen check: Welcome renders, but the first viewport exposes no tappable targets in the runtime accessibility snapshot and no visible primary action.

## Fixed In This Pass

- Replaced force casts in background task registration with guarded casts and failed task completion.
- Replaced trigger re-evaluation `DispatchQueue.main.asyncAfter` scheduling with cancellable Swift concurrency tasks.
- Reworked the location picker to use `NavigationStack`, modern toolbar placements, async MapKit search resolution, visible search error alerts, and automatic dismissal after selecting a result.
- Updated focused modal navigation flows from `NavigationView` to `NavigationStack`.
- Updated a weather forecast card to use a cancellable `.task`, hidden scroll indicators via `.scrollIndicators(.hidden)`, and the app's Liquid Glass surface direction instead of a UIKit-color material card.

## Priority 0: Correctness And App-Store Readiness

1. Replace placeholder production contact and policy values.
   - Current placeholders include `placeholder@example.com`, `https://example.com/terms`, and `https://example.com/privacy`.
   - A shipping app should use real support/privacy endpoints and matching privacy policy text.

2. Fix onboarding reachability.
   - The welcome screen must show an immediately discoverable primary action on the first viewport, or expose it reliably to VoiceOver and Switch Control.
   - The first action should be a real `Button`, not a gesture-only surface.

3. Audit background task configuration.
   - Confirm `BGTaskSchedulerPermittedIdentifiers` includes both weather refresh and trigger evaluation identifiers.
   - Inject the app `ModelContainer` into background managers instead of creating ad hoc containers in background code.
   - Add tests around duplicate task registration, unavailable background refresh, and trigger notification deduplication.

4. Replace silent or log-only user-action failures.
   - Location search now surfaces errors; repeat this pattern for settings links, exports, notification permissions, and privacy contact actions.

## Priority 1: Native Navigation And Interaction

1. Finish `NavigationView` migration.
   - Remaining files include weather alerts, reminder management components, detailed reminder components, manual location entry, location management components, notification preferences, data privacy, privacy contact, and export options.
   - Replace `.navigationBarLeading` / `.navigationBarTrailing` with `.topBarLeading` / `.topBarTrailing`.

2. Convert tappable rows from `onTapGesture` to `Button`.
   - Affected areas include tutorial bubbles, reminder management rows, notification preference options, privacy contact rows, data export rows, and settings storage rows.
   - Preserve visual styling with `.buttonStyle(.plain)` where needed.

3. Use item-driven sheets for selected models.
   - Several flows still use boolean sheet flags for selected or mutually exclusive state.
   - Move to enum/item-driven presentation so state cannot represent impossible combinations.

4. Make tab and route ownership explicit.
   - Keep `MainTabView` selection enum-based.
   - Add per-tab `NavigationStack` path ownership before adding deeper routing.

## Priority 2: Visual Design And HIG Alignment

1. Rebalance the visual language around native controls.
   - Keep Liquid Glass for meaningful grouped surfaces.
   - Avoid applying custom card treatments where `Form`, `List`, `ContentUnavailableView`, `LabeledContent`, `Gauge`, `Picker`, and native buttons better fit iOS.

2. Reduce one-off font and color styling.
   - Prefer semantic SwiftUI text styles and `foregroundStyle`.
   - Custom fonts should be opt-in for brand moments, not every dense settings or data surface.

3. Standardize spacing and surface constants.
   - Move spacing, corner radii, card padding, animation durations, and glass tint strength into a small design token namespace.
   - Make card radii and padding consistent across dashboard, reminders, settings, weather, and onboarding.

4. Improve empty and error states.
   - Use `ContentUnavailableView` for no reminders, no weather data, no search results, and disabled permission states.
   - Pair color status with symbols/text for Differentiate Without Color.

5. Make first-run onboarding feel native.
   - Keep animations short, interruptible, and Reduce Motion aware.
   - Replace staged text fade sequences with structural layout transitions and immediate controls.

## Priority 3: Accessibility

1. Verify every screen with Dynamic Type sizes through accessibility sizes.
   - Risk areas: dashboard cards, horizontal chips, forecast cards, weather metrics, and long reminder summaries.

2. Add semantic labels for complex visual components.
   - Weather cards, forecast charts, trigger likelihood indicators, icon-only buttons, badges, and progress indicators need meaningful VoiceOver output.

3. Respect Reduce Motion consistently.
   - Current onboarding and celebration flows use multiple delayed animations.
   - Centralize animation policy using `@Environment(\.accessibilityReduceMotion)`.

4. Guarantee 44x44 hit targets.
   - Check icon buttons, chip selectors, forecast day cards, close/done controls, and trailing row actions.

## Priority 4: SwiftUI Performance

1. Split large view files by feature component.
   - High-priority files: `DashboardView.swift`, `StreamlinedReminderCreationView.swift`, `FirstReminderCreationComponents.swift`, `NotificationPermissionView.swift`, `WeatherViewModel.swift`, and `LocationManagementComponents.swift`.
   - Keep one major type per file where practical.

2. Remove render-time derived work.
   - Move repeated filtering/sorting/formatting out of `body` and row builders.
   - Prefer FormatStyle-backed `Text` where output is purely display.

3. Reduce broad observation fan-out.
   - Continue the planned migration from `ObservableObject`/`@Published` to `@Observable` for lightweight ViewModels first.
   - Keep heavy Combine-backed services isolated behind narrower observable facades.

4. Replace non-cancellable delayed UI work.
   - Onboarding, celebration, tutorial, manual location entry, and reminder detail flows still use `DispatchQueue.main.asyncAfter`.
   - Move to `.task`, `Task.sleep(for:)`, and cancellation-aware animation state.

5. Profile before heavy visual redesign.
   - Use Instruments SwiftUI timeline and Time Profiler on dashboard scroll, reminder creation, weather dashboard refresh, and onboarding.
   - Record frame drops, main-thread time, memory peak, and largest invalidation sources before and after changes.

## Suggested Work Order

1. Fix onboarding reachability and accessibility semantics.
2. Replace placeholder production contact/privacy values.
3. Finish navigation and tap-gesture modernization.
4. Refactor dashboard/weather/reminder creation into smaller views.
5. Migrate low-risk ViewModels to `@Observable`.
6. Run accessibility and performance profiling passes.
7. Re-run unit tests and UI smoke tests once simulator XCTest launch is stable.
