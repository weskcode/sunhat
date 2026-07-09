# SunHat iPadOS Port Plan

Plan date: July 9, 2026
Scope: what it takes to turn SunHat from "builds and runs on iPad" into a real iPad experience worth screenshotting for the App Store. Planning only — no implementation in this pass.

## 1. Current State

- `TARGETED_DEVICE_FAMILY = "1,2"` is already set for both build configs (`SunHat.xcodeproj/project.pbxproj:340,377`), so the app already installs and runs on iPad today — as a scaled-up iPhone layout via Auto Layout/SwiftUI compatibility, not an iPad-optimized one.
- No `NavigationSplitView`, `horizontalSizeClass`, or other size-class-aware layout exists anywhere in `SunHat/Views/` (confirmed by repo search — zero hits).
- Every top-level screen (`DashboardView`, `WeatherView`, `AllRemindersView`, `SettingsView`, `StreamlinedReminderCreationView`) is a single-column `ScrollView`/`Form` sized for iPhone width. On iPad these will render as an oversized single column with large empty margins rather than using the extra width.
- `MainTabView` uses the iOS 26 `Tab`/`TabView` API with a detached "New Task" search-role button (`SunHat/Views/MainTabView.swift:44-70`). `TabView` on iPadOS can present as a sidebar automatically in some configurations, but the custom `.add`/search-role tab interception (`tabSelection` binding, `MainTabView.swift:28-39`) has not been verified against iPad's sidebar interaction model.
- SwiftData model container, App Group, and WeatherKit entitlement are already device-family-agnostic (`SunHat/sunhat.swift:51-89`, `SunHat/SunHat.entitlements`) — no data-layer changes needed to run on iPad.

## 2. Target Experience

Not a from-scratch redesign — reuse every ViewModel and service as-is (they're UI-framework agnostic per the MVVM rules in `CLAUDE.md`). The port is a **view-layer adaptation**, gated by `UIDevice.current.userInterfaceIdiom == .pad` or (preferred) `@Environment(\.horizontalSizeClass)`:

1. **Root navigation**: replace the flat `TabView` with `NavigationSplitView` on regular-width size classes (iPad landscape, and iPad portrait on 11"+/13" models), keeping the existing `TabView` for compact-width (iPad Slide Over, Split View at narrow widths). A `SunHatRootNavigation` wrapper view can pick between the two based on `horizontalSizeClass`, so `MainTabView` itself stays the compact-width implementation.
2. **Dashboard as a two-column layout**: sidebar/primary column = reminder list (reuse `AllRemindersView`'s row content), detail column = `DashboardView`'s hero weather card + selected reminder detail (reuse `DetailedReminderView`). This is the single highest-value change — it's the classic "list + detail" iPad pattern and reuses two already-built, already-tested views verbatim.
3. **Reminder creation as a form sheet, not full-screen**: `StreamlinedReminderCreationView` should present in a `.sheet` with `.presentationDetents` or as a fixed-width modal on iPad rather than edge-to-edge full screen, matching Apple's iPad HIG for modal forms.
4. **Settings as a two-column Form**: `SettingsView`'s existing `Form` sections (`SunHat/Views/Settings/SettingsView.swift:30-40`) map directly onto `NavigationSplitView`'s sidebar-of-sections pattern used by Apple's own Settings app on iPad — sidebar = section list, detail = the section's content.
5. **Multitasking**: verify Split View / Slide Over / Stage Manager behavior specifically for the glass tab bar and the detached "New Task" button, since `.tabBarMinimizeBehavior(.onScrollDown)` and the custom search-role tab interception are iOS 26 phone-first APIs that need explicit iPad-multitasking QA.

## 3. Concrete Steps

1. Add `@Environment(\.horizontalSizeClass)` branching at the root (`ContentView.swift`) between the existing `MainTabView` (compact) and a new `SunHatSplitView` (regular).
2. Build `SunHatSplitView`: `NavigationSplitView` with sidebar = reminders list + Weather/Settings sidebar items, detail = whichever is selected. Reuse `ReminderGlassCard`, `DetailedReminderView`, `WeatherView`, `SettingsView` unchanged.
3. Wrap `StreamlinedReminderCreationView` presentation in a size-class check: full-screen sheet on compact, fixed-width (`.frame(idealWidth: 420)`-ish) sheet on regular.
4. Add iPad simulator targets (`iPad Pro 13-inch`, `iPad mini`) to routine QA rotation once this lands — CLAUDE.md's "use only iPhone 17 Pro" rule is for routine iPhone validation and should get an iPad equivalent at that point.
5. Re-run existing `SunHatUITests` against an iPad destination — `DashboardUITests` and similar tab-bar-driven tests should mostly pass unchanged since they query by accessibility label, not layout, but confirm `NavigationSplitView`'s selection state doesn't break the `app.tabBars.buttons[...]` queries in compact mode.
6. Only after (1)-(5) land: capture iPad App Store screenshots (13" class, 2064×2752) per the `app-store-screenshots` skill — do not screenshot the current unadapted scaled layout, since that would misrepresent the product.

## 4. Effort & Risk

- **Effort**: medium. No new data/service work; this is pure SwiftUI view composition reusing existing pieces. The bulk of the work is `SunHatSplitView` plus multitasking QA.
- **Risk**: the custom tab-interception logic for the "New Task" button (`MainTabView.swift:28-39`) is the one piece of real novel logic and needs its own equivalent in the split-view sidebar (a toolbar button rather than a tab item) — don't try to reuse `MainTabView`'s binding trick verbatim inside `NavigationSplitView`.
- **Open question**: whether iPad should get a genuinely different information architecture (e.g., calendar-style multi-reminder overview) or just a wider version of the phone flow. This plan assumes the latter (lower risk, ships faster); revisit if a dedicated iPad-specific feature is wanted later.
