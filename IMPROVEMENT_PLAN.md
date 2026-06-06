# SunHat Improvement Plan

Last updated: June 5, 2026
Authored from an expert SwiftUI/iOS review (code review + platform-feature feasibility + product strategy).

---

## 1. The product in one sentence

SunHat fires reminders when **weather conditions** match, not when a clock does ("water the plants when it's above 70°F"). That condition-trigger loop is the entire product. Everything else is decoration on top of it.

**The core loop:** create reminder → background weather monitoring → trigger evaluation → notification.

> **Most important truth:** the core loop was silently broken until this session (missing `BGTaskSchedulerPermittedIdentifiers`). It is fixed in code but **has never been verified end-to-end on a physical device.** That verification is priority #1, ahead of every new feature.

---

## 2. Guiding principle: consolidate before expanding

The codebase is **over-built relative to the simplified product direction**, not under-built:

- `ComprehensiveReminderCreationViewModel` (31 KB) still exists alongside the streamlined creator that replaced it — two creation paths.
- `TriggerCondition` supports 7 trigger types (seasonal markers, historical comparison, consecutive days, composite humidity+wind); the simplified UI exposes a fraction.
- The notification model carries vibration patterns (incl. "SOS"), 9 sounds, grouping, and lock-screen behavior — all hidden from the simplified settings.
- `LegacyContentView` (147 lines), dead Dashboard sections, dead `appearanceSection`, unused `ScaleButtonStyle`, and an **unwired compact-surface layer** all ship as dead code.

Adding widgets/watch/Live Activities on top of an unverified core loop multiplies the surface area of "things that might silently not work." **Finish and verify the core, delete the dead weight, then expand.**

---

## 3. Phased roadmap

### Phase 0 — Correctness & crash safety (do first; mostly small)

| # | Item | File(s) | Risk |
|---|------|---------|------|
| 0.1 | **[DONE]** Fix latent `WeatherService.weatherActor!` crash reachable from background refresh before configuration | `WeatherService.swift`, `sunhat.swift` | was HIGH |
| 0.3 | **[DONE]** Fix `try! ModelContainer` in `WeatherView.init()` — now `WeatherViewModel()` + `configure(modelContainer:)` on `.task`, using the real app-group container | `WeatherView.swift`, `WeatherViewModel.swift` | was HIGH |
| 0.5 | **[DONE]** Removed `Double.random()`/`Int.random()` from `body` (deleted the dead `hourlyForecastSection` that contained them) | `DashboardView.swift` | was MED |
| 0.2 | **Device-verify the core loop**: install on hardware, create a reminder whose condition is currently true, background the app, confirm a notification arrives | — | HIGH (pending) |
| 0.4a | **[DONE]** Background notification path now gates on `reminder.canTrigger`, so a reminder whose condition stays true is no longer re-notified on every 15-min refresh; the cooldown is persisted in SwiftData (`lastTriggered` + `cooldownPeriodHours`) and survives launches. Also discovered the trigger-evaluation BG task is never bootstrapped (`scheduleBackgroundEvaluation()` is only self-rescheduled), so the live background notifier is `BackgroundWeatherManager` | `BackgroundWeatherManager.swift` | was MED |
| 0.4b | **[PENDING — needs device verification]** Unify the foreground `TriggerEngineManager` path: its `updateReminderWithResult` is a stub that doesn't persist `lastTriggered`, and its dedup is in-memory only. It should set the persistent cooldown (call `reminder.trigger()`) so foreground and background notifications share one source of truth. Requires wiring model access into the actor-based manager — do with on-device testing | `TriggerEngineManager.swift`, `TriggerEngine.swift` | MED (pending) |

### Phase 1 — Delete the dead weight (low risk, high clarity)

- **[DONE]** Deleted `LegacyContentView` (147 lines).
- **[DONE]** Deleted 6 unused Dashboard sections (`weatherAlertsSection`, `temperatureTrendSection`, `quickStatsSection`, `hourlyForecastSection`, `enhancedForecastSection`, `comprehensiveWeatherMetrics`) + 2 orphaned helpers (`calculateMinTemp`/`calculateMaxTemp`) + the now-unused `selectedForecastDays` state.
- **[DONE]** Deleted 6 orphaned components from `DashboardComponents.swift` (`DetailedWeatherCard`, `QuickStatCard`, `HourlyWeatherCard`, `EnhancedDayForecastRow`, `TemperatureBar`, `WeatherMetricCard`, `EmptyForecastView`) + the `ForecastRange` enum; also migrated the surviving `ActiveReminderCard`/`WeatherAlertCard` to `.glassEffect()` + `foregroundStyle`.
- **[DONE]** Wired `appearanceSection` into the Settings `Form` (the theme switcher was fully built but unreachable — now a working feature).
- **[DONE]** Deleted unused `ScaleButtonStyle`.
- **[DONE]** Deleted the unreachable comprehensive creation flow (`ComprehensiveReminderCreationView` + `ComprehensiveReminderCreationViewModel`, ~31 KB + `generateMockForecast`) and the unused `RealTimeWeatherCard` (`generateMockCurrentWeather`). Extracted the still-used `SectionHeaderView` into its own file first. Build + 222 tests green.
- **[DONE]** Removed all fabricated weather from the active creation flow. `FirstReminderCreationViewModel.loadWeather()` now makes ONE `WeatherService.fetchWeatherData` call that populates BOTH the "Current Location" card (temp/feels-like/condition, converted to the user's unit) AND the forecast that feeds trigger-likelihood (`WeatherCondition`→compact mapping, °F to match the trigger comparison). Deleted `generateEnhancedMockForecast`/`getCurrentSeasonalBaseTemp`/`getRealisticWeatherCondition` and the `fetchRealWeatherForecast` stub — on no-location/failure it shows empty/"unavailable", never fake data. Card verified on simulator; test updated to assert no-fabrication.
- **Active weather surfaces are all live now:** Dashboard, WeatherView, DetailedReminderView, and the streamlined create sheet all use real `WeatherService`/WeatherKit.
- **[DONE]** The last mock-weather generators (`RealTimeWeatherCard.generateMockCurrentWeather`, `ComprehensiveReminderCreationViewModel.generateMockForecast`) were in dead/deprecated code — both files deleted rather than wired. No fabricated weather data remains anywhere in the app.
- **Note:** `TemperatureTrendChart.swift` is now dead but intentionally retained — clean, self-contained, clearly meant for the deferred forecast feature.

### Phase 2 — Finish the design system (HIG / Liquid Glass)

- **[MOSTLY DONE]** Glass migration: migrated the clear card surfaces — `AllRemindersView` search bar + `ReminderGlassCard`, `DetailedReminderView` weather header (`.ultraThinMaterial` → `.glassEffect()`), and `DashboardComponents` cards (done in Phase 1). Remaining `.ultraThinMaterial` (2) is the `TutorialBubbleView` tooltip (intentionally left — small floating tooltip + a Shape-fill arrow). Remaining `Color(.secondarySystemBackground)` (29) are **intentionally not bulk-converted** — they're spread across 19 files in secondary/nested contexts (search fields, panels inside glass cards, onboarding insets) where glass-in-glass would be an anti-pattern; convert case-by-case only where a true top-level card surface is identified.
- **[DEFER to visual QA]** `GlassEffectContainer` wrapping: the documented use is tight glass clusters that morph (toolbars/button groups), not long scrolling card lists — wrapping a scroll `LazyVStack` risks unexpected merge/render. Evaluate with the app running before applying to DashboardView/WeatherView.
- **[DEFER to visual QA]** `AllRemindersView` → `.searchable`: a UX/behavior change (search moves to nav bar; needs a reliable `NavigationStack` ancestor). The custom search works today; convert with the app running.
- **[DONE]** Deprecated-API sweep (mechanical, app-wide): `foregroundColor` → `foregroundStyle` (624 sites), `.cornerRadius()` → `.clipShape(.rect(cornerRadius:))` (29), `.buttonStyle(PlainButtonStyle())` → `.buttonStyle(.plain)` (28), `.navigationBarHidden(true)` → `.toolbar(.hidden, for: .navigationBar)` (1). Build + tests green.
- Replace `AllRemindersView`'s hand-built search bar with `.searchable(text:)` (free clear button, scopes, accessibility).
- Reduce `.caption2` usage (95 sites) — it's below comfortable reading size; reserve for genuinely dense metadata.

### Phase 3 — Accessibility & Dynamic Type

- Add `.accessibilityElement(children: .combine)` + labels to forecast/hourly/metric cards in `DashboardComponents` (currently VoiceOver reads each fragment separately; `TemperatureBar` is unlabeled). Use `QuickStatCard` as the template — it's already correct.
- Audit fixed-width rows (`EnhancedDayForecastRow` widths 52/44/30) at accessibility Dynamic Type — add `minimumScaleFactor` or drop hard widths.
- The hero temperature uses a fixed 72pt font; keep but verify it doesn't clip at the largest sizes.

### Phase 4 — Extract `SunHatKit` shared framework (unblocks all extensions)

This is the **highest-leverage architectural move** and a prerequisite for widgets and watch.

> **Step-by-step Xcode instructions + drop-in widget code: [WIDGET_SETUP.md](WIDGET_SETUP.md).**
> **[DONE - prep]** `NextReadyReminderSnapshot` is now `Codable` (+ round-trip tests).
> **Blocked on Xcode GUI:** creating the framework + widget *targets* requires `project.pbxproj` surgery (synchronized folder groups) that is unsafe to do by hand — must be done via File ▸ New ▸ Target. Once targets exist, all remaining code is plain source files the agent can write.

- Create a `SunHatKit` Swift package / framework linked by app + (future) widget + (future) watch.
- Move into it: all 10 `@Model` classes; weather/trigger enums + the `Sendable` `…Display`/`…Transfer` DTOs + `ModelDataConverter`; the `Schema` definition (centralize it — divergence between app and extension schemas = migration crash); `NextReadyReminderSnapshot` (**add `Codable`**), `NextReadyReminderSelector`; and the WeatherKit-facing `AppleWeatherKitAPI` for fallback fetches.
- Build a **shared snapshot producer**: opens the app-group `ModelContainer` → fetches reminders → `NextReadyReminderSelector.snapshot(...)`. **Wire it into the live Dashboard too** — this closes the dead-code gap (the compact surface is currently unit-tested but unused).

### Phase 5 — WidgetKit (highest user value per unit effort; reuses Phase 4)

- `AppIntentTimelineProvider` so users configure which reminder/location the widget tracks.
- Read **cached `WeatherData` from the app-group store** (the store already caches with a 15-min expiry); call WeatherKit directly only as a stale-cache fallback (widget gets its own WeatherKit entitlement). **Never** use the `WeatherService.shared` singleton from the extension.
- Reload policy: `.after(30 min)` baseline + `WidgetCenter.shared.reloadAllTimelines()` from `BackgroundWeatherManager` refresh and after reminder create/edit/trigger.
- iOS 26: `containerBackground(.fill.tertiary, for: .widget)` + `widgetAccentable()` on icon/temp for tinted Home Screen and StandBy. Do **not** port `.glassEffect()` directly — widgets use system material.
- Families: `.systemSmall` + Lock Screen `.accessoryRectangular`/`.accessoryCircular` (map ~1:1 onto the snapshot fields).

### Phase 6 — watchOS (high value, moderate effort)

- Complication + glanceable screen showing the next-ready reminder (reuses Phase 4 snapshot).
- **Phone stays the single source of truth** for evaluation + notification delivery (notifications already mirror to a paired watch). Watch is read-only.
- **App Groups do NOT bridge phone↔watch** (common misconception). Push the `Codable` snapshot via `WatchConnectivity` application context / `transferCurrentComplicationUserInfo`.
- WeatherKit is available on watchOS if you want independent current-temp display.

### Phase 7 — Live Activities (deprioritize — marginal value)

- Honest assessment: SunHat's triggers are ambient/open-ended; a permanently-running "monitoring" activity is clutter. The only defensible case is a short-lived "approaching trigger" activity ("3° away, likely by 3 PM").
- Blocker: there is no canonical "distance to trigger" / ETA signal. `TriggerEvaluationResult.confidence` is a proxy; `WeatherViewModel` has **two divergent** likelihood heuristics and hardcoded ETA times (3 PM / 6 AM). Would require extracting one canonical `distanceToTrigger`/ETA function into the shared trigger layer first.
- **Recommendation: skip for v1; revisit only on user demand.**

---

## 4. Data-accuracy debt (affects triggers AND any widget that shows "current conditions")

The WeatherKit→model mapping has silent placeholders that will make condition triggers misfire:

- **[DONE]** `mapDailyWeather` now uses real `daily.precipitationAmount` (converted to inches) instead of hardcoded `0.0` — forecast "will it rain" triggers (`precipitationAmount > 0`) now work. Build-verified against the iOS 26.4 SDK.
- **[PENDING — needs model refactor]** `mapDailyWeather` still defaults `humidity: 50`, `cloudCover: 20` — WeatherKit's `DayWeather` genuinely exposes neither. Proper fix: make those DTO/model fields optional (`Int?`) to mean "unknown," or average the `hourlyForecast`, and have the trigger engine skip humidity/cloud conditions when the forecast value is unknown. (Inline comment added pointing here.)
- `mapCurrentWeather` sets `precipitationAmount: 0.0`, but current precipitation presence is already carried by `precipitationType` (mapped from the condition), so the current-weather "is it raining" checks still work.
- OpenWeatherMap forecast hardcodes `precipitationProbability: 0`, `dewPoint: 0` (backup provider is dormant — no API key — so low impact).
- `getBackgroundRefreshStatus()` returns the literal string `"Available"` (stub).

---

## 5. WeatherKit quota — a real scaling constraint

WeatherKit's free tier is ~500k calls/month. Current cadence (15-min weather + 10-min trigger eval) is ~4,300 weather calls/user/month, so **~115 active users saturate the free tier before widgets are added**. Widgets add their own timeline fetches. Mandatory mitigations: aggressive caching (already partially present), widgets read the cache rather than calling WeatherKit, and consider backing off refresh cadence when the app is backgrounded for long periods.

---

## 6. The most important developer questions — answered

1. **Does the core notification loop fire on a real device?** Unknown — config fixed this session, but `BGTaskScheduler` needs hardware verification. **#1 priority.**
2. **Will background polling blow the WeatherKit quota?** Yes around ~115 users on the free tier; caching + widget-reads-cache are mandatory.
3. **Do the two background tasks double-evaluate / double-notify?** Risk exists; pick one trigger-eval owner and persist a per-reminder last-notified timestamp.
4. **Is the data layer ready for a widget/watch?** App group + shared store are correct (the strongest part). Blocker: `@Model`s are app-internal — need the `SunHatKit` framework (Phase 4).
5. **How much of the trigger engine is actually reachable by users?** A fraction; the engine is heavier than the product. Consolidate.
6. **Biggest code-health liability?** 672 `foregroundColor` + dead code + duplicate creation VMs + 7 `ObservableObject` VMs. Mechanical but large.
7. **No permission / no network?** Handled gracefully (dashboard unavailable states, surfaced location errors).
8. **Is the "compact surface for widgets" real?** The types exist and are tested but are **dead code** — not wired in, not `Codable`, not in a shared target. (CLAUDE.md corrected.)

---

## 7. Recommended execution order (TL;DR)

1. **Phase 0** — device-verify the loop + crash/correctness fixes. *Nothing else matters until 0.2 passes.*
2. **Phase 1** — delete dead weight.
3. **Phase 2–3** — finish glass migration, deprecated-API sweep, accessibility.
4. **Phase 4** — extract `SunHatKit` (unblocks extensions).
5. **Phase 5** — WidgetKit (best ROI).
6. **Phase 6** — watchOS complication.
7. **Phase 7** — Live Activities only if users ask.
