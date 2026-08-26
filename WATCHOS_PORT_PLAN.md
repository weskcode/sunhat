# SunHat watchOS Port Plan

Plan date: July 9, 2026
Scope: what it takes to ship a real Apple Watch companion for SunHat. Planning only, no implementation in this pass. There is currently no watchOS target in `SunHat.xcodeproj` (confirmed via `xcodebuild -list`: targets are `SunHat`, `SunHatTests`, `SunHatUITests` only).

## 1. Current State, what's already built for this

SunHat already has the one piece of infrastructure a watch surface actually needs, built and unit-tested ahead of time:

- `NextReadyReminderSnapshot` (`SunHat/Models/NextReadyReminderSnapshot.swift:11-25`), a `Codable`, `Sendable` struct explicitly documented as designed "to back a WidgetKit `TimelineEntry` and travel over `WatchConnectivity` to a watch complication." It carries exactly what a glance/complication needs: title, subtitle, icon name, ready state.
- `NextReadyReminderSelector.snapshot(from:)` (`NextReadyReminderSnapshot.swift:27-54`), pure function that picks the single highest-priority "ready now" reminder from a list of `WeatherReminderDisplay`, with tested sort logic (priority, then recency). Covered by `SunHatTests/NextReadyReminderSelectorTests.swift`.
- `NextReadyReminderCompactView` (`SunHat/Views/Components/NextReadyReminderCompactView.swift`), already renders this snapshot as a small SwiftUI view, wired into `DashboardView` today.

What's missing is entirely the **transport and target**, not the data model: there is no watchOS app target, no WidgetKit extension, and no `WatchConnectivity` session anywhere in the repo.

## 2. Key Architectural Fact: App Group Alone Does Not Reach the Watch

`SunHat.entitlements` already shares `group.org.wesley.sunhat` (`SunHat/SunHat.entitlements:9`), and `sunhat.swift` already points the SwiftData store at that shared container (`SunHat/sunhat.swift:56-68`). That's sufficient for an **iPhone-hosted WidgetKit extension** (home screen widget, Lock Screen widget), a widget extension runs on the same physical device and can read the same App Group container directly.

It is **not** sufficient for a physical Apple Watch. The Watch is a separate physical device with its own file system; nothing in an iPhone's App Group container is visible to it. Getting `NextReadyReminderSnapshot` onto the wrist requires one of:

- **`WatchConnectivity`** (`WCSession`), send `NextReadyReminderSnapshot` as an `updateApplicationContext` (latest-value-wins background delivery) or a `transferUserInfo` call whenever the "ready now" reminder changes. Simplest, no server involved, matches the snapshot's own doc comment, and fits CLAUDE.md's "no data sharing" / privacy-first stance (device-to-paired-device only, no CloudKit round trip required).
- **CloudKit sync**, `CLAUDE.md` already lists this as "prepared but disabled" (`ModelConfiguration(.cloud)` swap in `sunhat.swift:56-63`) for cross-device sync generally. Heavier lift (needs CloudKit container provisioning, schema, and a re-enable pass) but would also solve iPhone/iPad sync as a side effect, and is the right long-term answer if the watch app should work even when the iPhone is out of Bluetooth range.

Recommendation: **start with WatchConnectivity.** It directly consumes the snapshot type that already exists, needs zero CloudKit provisioning, and matches the "compact surface" framing already in the codebase. Revisit CloudKit later if untethered watch operation becomes a requirement.

## 3. Target Scope (v1)

Keep the first watchOS release intentionally small, a glance companion, not a full port of the trigger-creation UI:

1. **Watch complication / glance**: shows `NextReadyReminderSnapshot` (title, icon, "ready now" state), this is a direct UI consumer of code that already exists and is tested.
2. **Watch app home screen**: a short list of active reminders (title + one-line trigger summary), read-only. Reuse `WeatherReminderDisplay`'s existing computed summary logic (already used by `NextReadyReminderSnapshot`) rather than inventing new formatting.
3. **Tap-to-open-iPhone** for anything beyond viewing (creating/editing a reminder), v1 should not reimplement `StreamlinedReminderCreationView` on a 41mm screen.
4. **No independent notifications in v1**, let the iPhone keep owning notification delivery (`BackgroundWeatherManager`/`TriggerEngineManager`) rather than duplicating trigger evaluation on-watch; the watch app only displays state the phone already computed.

## 4. Concrete Steps

1. **New Xcode target**: add a watchOS App target (Xcode's "Watch App" template, paired to the existing `SunHat` target) via Xcode's GUI, per project memory, adding targets requires the Xcode GUI, not source-file edits.
2. **Shared framework extraction**: per `CLAUDE.md`'s existing note, `NextReadyReminderSnapshot`, `NextReadyReminderSelector`, and the `WeatherReminderDisplay` type they depend on need to move into a shared Swift package/framework (`SunHatKit`) importable by both the iOS app and the new watch target, right now they live directly in the `SunHat` target and aren't reachable from a separate target without duplication.
3. **`WatchConnectivity` session wrapper**: a small `SunHatWatchSession` actor on the iPhone side (in `SunHat/Services/`) that activates `WCSession`, observes reminder/weather changes (likely the same signal that already refreshes `NextReadyReminderCompactView` on `DashboardView`), and pushes an updated `NextReadyReminderSnapshot` via `updateApplicationContext`.
4. **Watch-side receiver**: mirrored `WCSessionDelegate` in the watch target that decodes the snapshot and updates the watch app's `@Observable` view state, plus a `WidgetKit` `TimelineProvider` for the complication that reads the last-received snapshot from watch-local storage (e.g. a small `UserDefaults`/App Group on the watch side, watchOS apps get their own App Group container, separate from the phone's).
5. **Testing**: unit-test the `WatchConnectivity` wrapper with a fake `WCSession` the same way `WeatherProviding`/`LocationManaging` are faked today (CLAUDE.md's existing dependency-injection pattern extends cleanly here).
6. **Only after (1)-(5) ship**: capture watch App Store screenshots (Series 11/10 class, 416×496) per the `app-store-screenshots` skill.

## 5. Effort & Risk

- **Effort**: medium-high. The data model and its tests already exist, the work is almost entirely new target setup, the `SunHatKit` extraction, and the `WatchConnectivity` plumbing, none of which currently exists in any form.
- **Risk**: `SunHatKit` extraction touches how `SunHat`'s own target imports these types (from same-target access to cross-module), which is a mechanical but real refactor across every file that currently uses `WeatherReminderDisplay`/`NextReadyReminderSnapshot` without an import statement.
- **Risk**: watchOS App Group containers are per-platform, confirm entitlement/provisioning-profile setup for the watch target's own `group.org.wesley.sunhat` (or a watch-specific group) before assuming data just "shows up."
- **Open question**: whether v1 should ship as a **WidgetKit-only complication** (much smaller scope, no full watch app UI, still requires the `WatchConnectivity` transport) versus a full watch app with its own reminder list screen. This plan's step 3 (target scope) assumes the fuller version; the complication-only version is a strict subset and a reasonable "ship something small first" fallback if timeline is tight.
