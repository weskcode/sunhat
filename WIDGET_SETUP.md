# SunHat — Widget & Shared Framework Setup (Xcode steps + drop-in code)

This is the handoff for the shared-framework + WidgetKit work tracked in [TODO.md](TODO.md) ("New surfaces"): extract a shared framework and add a WidgetKit extension.

## Why these steps must happen in Xcode (not via the agent)

The project uses **Xcode 16 synchronized folder groups** (`PBXFileSystemSynchronizedRootGroup`) and has exactly 3 targets. Creating a new **framework target** and a **widget-extension target** requires fabricating new `PBXNativeTarget` + synchronized-group entries, "Embed Frameworks"/"Embed App Extensions" build phases, product references, and dozens of cross-referenced unique IDs in `project.pbxproj`. A single malformed/duplicate ID makes Xcode refuse to open the project. This is the canonical **File ▸ New ▸ Target** operation.

**Key payoff:** once a target exists, synchronized groups pick up any source file added to its folder **automatically** — so after you do the GUI steps below, the agent can write all the widget/framework Swift code with no further `.pbxproj` editing.

---

## Code prep already done (safe, in-app, verified)

- `NextReadyReminderSnapshot` is now `Codable` (+ round-trip tests) — ready to back a `TimelineEntry` and travel over `WatchConnectivity`.
- The data path the widget will reuse already exists: `WeatherModelActor.fetchActiveRemindersForDisplay()` → `[WeatherReminderDisplay]` → `NextReadyReminderSelector.snapshot(from:)` → `NextReadyReminderSnapshot`.

---

## Step 1 — Create the `SunHatKit` framework target (Xcode)

1. **File ▸ New ▸ Target… ▸ Framework.** Name: `SunHatKit`. Embed in app: yes.
2. Set its **iOS Deployment Target to 26.4** and Swift Language Version to match the app.
3. Add `SunHatKit` to **Frameworks, Libraries, and Embedded Content** of the **SunHat** app target (and the **SunHatTests** target, and later the widget target).

### Move these files into `SunHatKit/` (drag in Xcode, or move on disk — synchronized groups will track them)

Make each type `public` as you move it (SwiftData `@Model` classes, enums, DTOs, and the snapshot/selector). The compiler will tell you what needs `public`/`public init`.

- All 10 `@Model` classes: `WeatherReminder`, `TriggerCondition`, `LocationData`, `WeatherData`, `ForecastDay`, `NotificationConfig`, `ReminderHistory`, `UserPreferences`, `SavedLocation`, `LocationHistory`.
- Weather/trigger enums + DTOs: `WeatherTypes.swift`, `WeatherCondition+Display.swift`, `ReminderCategory`/`ReminderPriority` (in `WeatherReminder.swift`), `TriggerType`/`ComparisonType`, and the `Sendable` `…Display`/`…Transfer` DTOs + the converter in `WeatherModelActor.swift`.
- `NextReadyReminderSnapshot.swift` (snapshot + `NextReadyReminderSelector`).
- The `Schema` definition — **centralize it** as a `public static let sunHatSchema = Schema([...])` in `SunHatKit` and have both `sunhat.swift` and the widget build their `ModelContainer` from it. (Divergent schemas between app and widget = migration crash.)

### Centralized container helper (add to `SunHatKit`)

```swift
import SwiftData

public enum SunHatStore {
    public static let appGroupID = "group.org.wesley.sunhat"

    public static let schema = Schema([
        WeatherReminder.self, TriggerCondition.self, LocationData.self,
        WeatherData.self, ForecastDay.self, NotificationConfig.self,
        ReminderHistory.self, UserPreferences.self, SavedLocation.self, LocationHistory.self
    ])

    /// Read-only-friendly container pointing at the shared app-group store.
    public static func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier(appGroupID),
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}
```

Then `sunhat.swift` becomes `try SunHatStore.makeContainer()` instead of the inline schema.

---

## Step 2 — Create the widget extension target (Xcode)

1. **File ▸ New ▸ Target… ▸ Widget Extension.** Name: `SunHatWidget`. Uncheck "Include Live Activity" for v1. Include Configuration Intent: yes (for choosing which reminder/location).
2. **Signing & Capabilities** on `SunHatWidget`:
   - Add **App Groups** → check `group.org.wesley.sunhat`.
   - Add **WeatherKit** (only needed if you do the stale-cache fallback fetch; otherwise omit).
3. Add `SunHatKit` to the widget target's **Frameworks, Libraries, and Embedded Content**.

---

## Step 3 — Widget code (drop into `SunHatWidget/` after the target exists)

The widget reads the **cached** store; it should not hammer WeatherKit (quota — see the WeatherKit quota note in TODO.md).

```swift
import WidgetKit
import SwiftUI
import SwiftData
import SunHatKit

struct SunHatEntry: TimelineEntry {
    let date: Date
    let snapshot: NextReadyReminderSnapshot
}

struct SunHatProvider: TimelineProvider {
    func placeholder(in context: Context) -> SunHatEntry {
        SunHatEntry(date: .now, snapshot: .unavailable)
    }

    func getSnapshot(in context: Context, completion: @escaping (SunHatEntry) -> Void) {
        completion(SunHatEntry(date: .now, snapshot: currentSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SunHatEntry>) -> Void) {
        let entry = SunHatEntry(date: .now, snapshot: currentSnapshot())
        // Weather changes slowly + app refreshes every 15 min; reload in 30.
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(30 * 60))))
    }

    @MainActor
    private func currentSnapshot() -> NextReadyReminderSnapshot {
        guard let container = try? SunHatStore.makeContainer() else { return .unavailable }
        let context = ModelContext(container)
        guard let reminders = try? context.fetch(FetchDescriptor<WeatherReminder>()) else {
            return .unavailable
        }
        // Reuse the existing converter from SunHatKit to build [WeatherReminderDisplay],
        // then NextReadyReminderSelector.snapshot(from:). (Expose a public
        // `WeatherReminderDisplay(from:)` or converter in SunHatKit during Step 1.)
        let displays = reminders.map(WeatherReminderDisplay.init(from:))
        return NextReadyReminderSelector.snapshot(from: displays)
    }
}

struct SunHatWidgetView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: SunHatEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: entry.snapshot.systemImageName)
                .font(.title2)
                .widgetAccentable()
            Text(entry.snapshot.title)
                .font(.headline)
                .widgetAccentable()
                .lineLimit(1)
            Text(entry.snapshot.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

@main
struct SunHatWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SunHatWidget", provider: SunHatProvider()) { entry in
            SunHatWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Ready Task")
        .description("Shows your next weather task that's ready to go.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryCircular])
    }
}
```

Notes:
- **Do not** port `NextReadyReminderCompactView`'s `.glassEffect()` — widgets use system material via `containerBackground`; use `widgetAccentable()` for the tinted Home Screen / StandBy.
- Add `WidgetCenter.shared.reloadAllTimelines()` in the app at the end of `BackgroundWeatherManager.handleBackgroundTask`/`manualRefresh()` and after a reminder is created/edited/triggered, so the widget tracks the app's refresh cadence without needing its own background execution.

---

## Step 4 — After the targets exist

Tell the agent "the SunHatKit and SunHatWidget targets exist" and it can: finish the `public` access-control pass, add `WeatherReminderDisplay(from:)` to SunHatKit, wire `WidgetCenter` reloads, and write widget unit tests — all as plain source files in the new folders (no `.pbxproj` editing required).

## watchOS (later, same pattern)

A watch complication reuses `NextReadyReminderSnapshot` (now `Codable`). **App Groups do not bridge phone↔watch** — push the snapshot via `WatchConnectivity` (`transferCurrentComplicationUserInfo`) from the phone, which stays the single owner of trigger evaluation + notifications.
