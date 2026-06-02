# SunHat HIG, Design, and Performance Audit Plan

## Current Verification

- Unit tests: `SunHatTests` passed on the existing configured iPhone 17 Pro simulator (`127 passed, 0 failed`) on June 2, 2026.
- Compile: compile-only simulator build passed with no warnings or errors after the latest cleanup on June 2, 2026.
- UI tests: not rerun after the latest changes. Swift Testing does not support UI tests, and the prior UI-test runner timed out during Xcode launch setup.
- Simulator policy: use the single configured simulator only. Do not clone or repeatedly launch additional simulators for routine validation.

## Completed In Recent Passes

- Replaced force casts in background task registration with guarded casts and failed task completion.
- Replaced trigger re-evaluation `DispatchQueue.main.asyncAfter` scheduling with cancellable Swift concurrency tasks.
- Reworked the location picker to use `NavigationStack`, modern toolbar placements, async MapKit search resolution, visible search error alerts, and automatic dismissal after selecting a result.
- Updated focused modal navigation flows from `NavigationView` to `NavigationStack`.
- Updated a weather forecast card to use a cancellable `.task`, hidden scroll indicators via `.scrollIndicators(.hidden)`, and the app's Liquid Glass surface direction instead of a UIKit-color material card.
- Made `StreamlinedReminderCreationView` the normal creation flow.
- Removed color and icon pickers from the main creation flow; activity-based appearance defaults now apply automatically.
- Reduced visible settings scope to location, notifications, temperature unit, privacy, and about.
- Simplified notification settings to notifications on/off, quiet hours, and daily maximum.
- Reduced onboarding animation staging and kept location and notification permission requests on dedicated explanation pages.
- Replaced the old floating create button with `GlassCreateTaskButton`.
- Converted key empty states to `ContentUnavailableView`.
- Removed global Inter/custom display typography in favor of system typography and Dynamic Type text styles.
- Added a minimal `NextReadyReminderSnapshot` and compact view contract for future widget/watch surfaces.
- Split dashboard support cards/forecast rows into `DashboardComponents.swift`.
- Moved weather condition display mapping and location dependency adapters out of `WeatherViewModel.swift`.
- Removed the dead commented legacy implementation from `WeatherViewModel.swift`.

## Priority 0: Correctness And App-Store Readiness

1. [x] Replace placeholder production contact and policy values in code.
   - Scattered placeholder email, terms, and privacy values were replaced with `AppSupportLinks`.
   - Circle back before release to confirm the final `sunhat.app` URLs and support/privacy email inboxes are owned and monitored.

2. [ ] Verify onboarding reachability visually and with accessibility snapshots.
   - Recent code removed staged animation delays, but a fresh visual/accessibility pass still needs to confirm the primary action is visible and reachable on first viewport sizes.
   - The first action should remain a real `Button`, not a gesture-only surface.

3. [ ] Audit background task configuration.
   - Confirm `BGTaskSchedulerPermittedIdentifiers` includes both weather refresh and trigger evaluation identifiers.
   - Inject the app `ModelContainer` into background managers instead of creating ad hoc containers in background code.
   - Add tests around duplicate task registration, unavailable background refresh, and trigger notification deduplication.

4. [ ] Replace silent or log-only user-action failures.
   - Location search now surfaces errors; repeat this pattern for settings links, exports, notification permissions, and privacy contact actions.

5. [ ] Add actual widget/watch targets if they are still desired.
   - The current project tree has no separate WidgetKit or watchOS source targets.
   - The implemented compact snapshot/view should be used as the boundary: show only the next ready reminder or one unavailable state.

## Priority 1: Native Navigation And Interaction

1. [x] Finish `NavigationView` migration.
   - `SunHat/Views` no longer contains `NavigationView`, `.navigationBarLeading`, or `.navigationBarTrailing`.

2. [x] Convert tappable rows from `onTapGesture` to explicit controls.
   - `SunHat/Views` no longer contains `onTapGesture`.
   - Visual styling was preserved with `.buttonStyle(.plain)` where needed.

3. [x] Use item-driven sheets for major mutually exclusive presentations.
   - Converted settings, data privacy, location management, dashboard, reminder management, and detailed reminder multi-sheet state to enum/item-driven presentation.
   - Also cleaned up remaining creation/location sheet booleans in all reminders, weather, and retired comprehensive creation screens.
   - Circle back opportunistically for any remaining single-purpose sheets where selected model state or impossible combinations can occur.

4. [ ] Make tab and route ownership explicit.
   - Keep `MainTabView` selection enum-based.
   - Add per-tab `NavigationStack` path ownership before adding deeper routing.

## Priority 2: Visual Design And HIG Alignment

1. [x] Rebalance the visual language around native controls.
   - Keep Liquid Glass for meaningful grouped surfaces.
   - Avoid applying custom card treatments where `Form`, `List`, `ContentUnavailableView`, `LabeledContent`, `Gauge`, `Picker`, and native buttons better fit iOS.

2. [x] Reduce global custom typography.
   - Prefer semantic SwiftUI text styles and `foregroundStyle`.
   - Inter and explicit `SF Pro Display` calls have been removed from the current Swift source.

3. [ ] Standardize spacing and surface constants.
   - Move spacing, corner radii, card padding, animation durations, and glass tint strength into a small design token namespace.
   - Make card radii and padding consistent across dashboard, reminders, settings, weather, and onboarding.

4. [x] Improve the highest-value empty states.
   - Use `ContentUnavailableView` for no reminders, no weather data, no search results, and disabled permission states.
   - Completed for all reminders, reminder management, saved locations, location history, and weather alerts.
   - Circle back for weather data, permission-disabled, and any remaining niche empty states.
   - Pair color status with symbols/text for Differentiate Without Color.

5. [x] Make first-run onboarding feel simpler.
   - Keep animations short, interruptible, and Reduce Motion aware.
   - Replace staged text fade sequences with structural layout transitions and immediate controls.
   - Circle back for a visual QA pass across screen sizes.

## Priority 3: Accessibility

1. [ ] Verify every screen with Dynamic Type sizes through accessibility sizes.
   - Risk areas: dashboard cards, horizontal chips, forecast cards, weather metrics, and long reminder summaries.

2. [ ] Add semantic labels for complex visual components.
   - Weather cards, forecast charts, trigger likelihood indicators, icon-only buttons, badges, and progress indicators need meaningful VoiceOver output.

3. [ ] Respect Reduce Motion consistently.
   - Current onboarding and celebration flows use multiple delayed animations.
   - Centralize animation policy using `@Environment(\.accessibilityReduceMotion)`.

4. [ ] Guarantee 44x44 hit targets.
   - Check icon buttons, chip selectors, forecast day cards, close/done controls, and trailing row actions.

## Priority 4: SwiftUI Performance

1. [ ] Continue splitting large view files by feature component.
   - High-priority files: `DashboardView.swift`, `StreamlinedReminderCreationView.swift`, `Views/Reminders/Creation/`, `NotificationPermissionView.swift`, `WeatherViewModel.swift`, and `Views/Location/`.
   - Completed first dashboard component extraction and weather view model support extraction.
   - Keep one major type per file where practical.

2. [ ] Remove render-time derived work.
   - Move repeated filtering/sorting/formatting out of `body` and row builders.
   - Prefer FormatStyle-backed `Text` where output is purely display.

3. [ ] Reduce broad observation fan-out.
   - Continue the planned migration from `ObservableObject`/`@Published` to `@Observable` for lightweight ViewModels first.
   - Keep heavy Combine-backed services isolated behind narrower observable facades.

4. [ ] Replace non-cancellable delayed UI work.
   - Onboarding, celebration, tutorial, manual location entry, and reminder detail flows still use `DispatchQueue.main.asyncAfter`.
   - Move to `.task`, `Task.sleep(for:)`, and cancellation-aware animation state.

5. [ ] Profile before heavy visual redesign.
   - Use Instruments SwiftUI timeline and Time Profiler on dashboard scroll, reminder creation, weather dashboard refresh, and onboarding.
   - Record frame drops, main-thread time, memory peak, and largest invalidation sources before and after changes.

## Suggested Work Order

1. Verify onboarding reachability and accessibility semantics visually.
2. Confirm final production contact/privacy endpoints are owned and monitored.
3. Add actual WidgetKit/watchOS targets only if product scope still calls for them, using the compact next-ready reminder contract.
4. Refactor dashboard/weather/reminder creation into smaller views.
5. Migrate low-risk ViewModels to `@Observable`.
6. Run accessibility and performance profiling passes.
7. Re-run unit tests after each change and run UI smoke tests only when the single simulator is stable.
