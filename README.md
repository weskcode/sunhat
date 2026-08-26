<h1 align="center">SunHat</h1>

<p align="center">
  <strong>Reminders that wait for the right weather.</strong>
</p>

<p align="center">
  <a href="https://github.com/keetchcode/sunhat/actions/workflows/ios-build.yml"><img src="https://github.com/keetchcode/sunhat/actions/workflows/ios-build.yml/badge.svg" alt="iOS Build"></a>
  <img src="https://img.shields.io/badge/Platform-iOS%2026.4+-blue" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-6.2-orange" alt="Swift">
  <img src="https://img.shields.io/badge/Xcode-26.4+-blue" alt="Xcode">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License: MIT"></a>
</p>

<p align="center">
Most reminder apps ask <em>when</em>. SunHat asks <em>what conditions</em>. Set "water the garden when it's been dry for 48 hours" or "golden hour photo walk when it's above 68°F and clear," and SunHat watches the forecast and notifies you when reality matches your intent.
</p>

<p align="center">
  Built for iOS 26 with SwiftUI, SwiftData, and WeatherKit.<br/>
  No accounts, no tracking, no third-party dependencies.
</p>

---

## Screenshots

<p align="center">
  <img src="AppStore/Screenshots_v2/Framed/01_iOS_Hero.png" width="200" alt="Hero — Weather-Smart Reminders" />
  &nbsp;&nbsp;
  <img src="AppStore/Screenshots_v2/Framed/02_TimerStyle_ExactMatch.png" width="200" alt="Exact Match Trigger" />
  &nbsp;&nbsp;
  <img src="AppStore/Screenshots_v2/Framed/03_Differentiator_Predictions.png" width="200" alt="Smart Weather Predictions" />
  &nbsp;&nbsp;
  <img src="AppStore/Screenshots_v2/Framed/08_ActiveReminders_List.png" width="200" alt="Active Reminders" />
</p>

<p align="center">
  <em>Light &amp; dark modes — <a href="AppStore/Screenshots_v2/FramedDark/">see dark variants</a></em>
</p>

---

## Features

- **Weather-triggered reminders** — 7 trigger types: exact temperature, temperature range, sky conditions, feels-like, dry period, consecutive days, and composite (temperature + humidity + wind)
- **Smart predictions** — forecast-based confidence scoring shows when conditions are likely to be met
- **Background monitoring** — iOS BackgroundTasks framework checks weather every 15 minutes and notifies you when conditions align
- **Hourly forecast dashboard** — real WeatherKit hourly data, not synthesized
- **Temperature history** — trend charts with yesterday, last week, and monthly averages
- **Quiet hours & daily limits** — control when and how often you get notified
- **Manual city selection** — use GPS or pick any city manually
- **App Intents & Shortcuts** — create reminders from Siri and Shortcuts
- **Spotlight indexing** — find reminders from iOS search
- **Data export & deletion** — full GDPR compliance with schema-parity tests
- **Liquid Glass UI** — native iOS 26 design language with `.glassEffect()` surfaces
- **Zero tracking** — no accounts, no analytics, no third-party SDKs

---

## Why this exists

A calendar reminder for "go for a run" fires whether it's sunny or sleeting. SunHat's premise is that some plans are conditional, not scheduled — and the phone already knows the weather. The whole app is built around one loop:

> **Describe the conditions → SunHat watches the forecast → you get notified when they're met.**

Everything in the codebase should serve that loop. Features that don't are worth questioning.

## Principles

These are the constraints the code is held to. They're worth reading before contributing.

1. **Never invent weather data.** If the provider has no hourly forecast, the UI says so — it does not synthesize plausible-looking numbers. Historical comparisons show "Not enough history yet" rather than a placeholder. This rule has teeth: several past changes were reverted for breaking it, and there are regression tests guarding it.
2. **Never imply official authority.** SunHat's threshold notices are branded "SunHat … Advisory" with the exact threshold disclosed. They are not government or WeatherKit severe-weather alerts and must never look like them.
3. **Privacy is a feature, not a page.** Location stays on-device. Coordinates go only to the weather provider, only to fetch a forecast. "Delete all my data" must actually delete everything, including state stored outside SwiftData.
4. **Controls must do what they say.** A toggle that doesn't persist, or a screen that doesn't work, gets deleted rather than shipped.

## Requirements

| | |
|---|---|
| Xcode | 26.4+ (currently building against Xcode 27 beta — see note below) |
| Swift | 6.2 |
| Minimum iOS | 26.4 |
| Dependencies | None — Apple frameworks only |

> **No CocoaPods, no SPM packages, no Carthage.** Every import is an Apple framework.

## Getting started

```bash
git clone https://github.com/keetchcode/sunhat.git
cd sunhat
open SunHat.xcodeproj
```

Build and run (`⌘R`). Tests are `⌘U`.

From the command line:

```bash
xcodebuild -scheme SunHat -configuration Debug -destination 'generic/platform=iOS Simulator' build
```

```bash
xcodebuild -scheme SunHat -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SunHatTests test
```

### WeatherKit setup

Live weather requires a WeatherKit entitlement tied to your own Apple Developer team:

1. Enable the **WeatherKit** capability for your App ID in the Apple Developer portal.
2. Change `PRODUCT_BUNDLE_IDENTIFIER` to something you own (it ships as `org.wesley.sunhat`).
3. Regenerate your provisioning profile *after* adding the capability — a profile created before it will fail at runtime.

Without it the app builds and runs, but weather fetches fail. Failures log the raw provider error under subsystem `org.wesley.sunhat`, category `AppleWeatherKitAPI` (visible in Console.app).

## Architecture

MVVM over SwiftData, with protocol seams for anything that touches the outside world.

```
SunHat/
├── Models/          SwiftData @Model types (WeatherReminder, TriggerCondition, WeatherData…)
├── ViewModels/      Presentation state; @Observable for new code, ObservableObject where Combine remains
├── Views/           SwiftUI, grouped by feature (Dashboard, Weather, Reminders, Settings, Onboarding)
├── Services/
│   ├── Weather/     WeatherKit provider + caching behind `WeatherProviding`
│   ├── Trigger/     Condition evaluation engine (the core logic)
│   ├── Location/    CoreLocation wrapper behind `LocationManaging`
│   └── Notifications/  Deep-link handoff, data clearing, category registry
└── Utilities/       Theme, motion, formatting helpers
```

**The trigger engine is the heart of the app.** `TriggerEngine+ForecastAnalysis.swift` evaluates whether current or forecast conditions satisfy a reminder's `TriggerCondition`. It's the most correctness-sensitive code in the project and has the densest test coverage. Changes there need tests.

**Dependency-injection seams** — `WeatherProviding`, `LocationManaging`, `SettingsOpening`, `NotificationPermissionProviding` — exist so view models can be tested without hitting the network, GPS, or the system. Use them; don't reach for singletons in new code.

### Design language

iOS 26 Liquid Glass. Card surfaces use `.glassEffect()`; page backgrounds use `Color(.systemBackground)`. Avoid `.regularMaterial` (superseded) and avoid nesting glass inside glass. Respect `accessibilityReduceMotion` for anything animated.

## Testing

Unit tests live in `SunHatTests/` (Swift Testing for new suites, XCTest for older ones). UI tests in `SunHatUITests/` are XCTest-only.

`ScreenshotCaptureUITests` drives real interactive flows and doubles as App Store screenshot generation.

**Simulator note:** the app's location permission affects test outcomes. `notDetermined` triggers a system permission dialog the UI tests don't dismiss; `denied` fails dashboard tests that assert a clean initial state. Keep it granted:

```bash
xcrun simctl privacy <device-udid> grant location org.wesley.sunhat
```

## Project status

Version 1.0, iPhone-first, preparing for App Store submission. Not yet shipped.

**Working:** weather-triggered reminders across 7 trigger types, background monitoring, notifications, App Intents/Shortcuts, Spotlight indexing, data export and deletion, notification deep-linking, complete privacy deletion.

**Tested:** 258+ unit tests across 50+ suites covering trigger engine correctness, weather service cancellation, privacy deletion parity, notification delivery, and location persistence.

**Planned:** WidgetKit and Lock Screen widgets, watchOS complication, iPad-optimized layout, CloudKit sync (prepared in code, needs provisioning), String Catalog localization (all copy is currently inline English).

Widgets and watchOS both need a shared `SunHatKit` framework target first — see [WIDGET_SETUP.md](WIDGET_SETUP.md), [WATCHOS_PORT_PLAN.md](WATCHOS_PORT_PLAN.md), and [IPAD_PORT_PLAN.md](IPAD_PORT_PLAN.md).

Live work is tracked in [TODO.md](TODO.md); the standing code audit and its resolution log are in [CODE_AUDIT.md](CODE_AUDIT.md).

### Toolchain note

The project targets Xcode 26.4 / Swift 6.2, but currently builds against the Xcode 27 beta, which is stricter about actor isolation for protocol conformances and introduced a `LinearGradient` `.opacity` ambiguity. Both are handled in-tree with explanatory comments. If you're on the released Xcode, the code still compiles.

> **CI runs on `macos-latest`** via GitHub Actions. The build-for-testing step uses the `SunHatUnitTests` scheme.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The short version: keep the weather-trigger loop central, never fabricate data, add tests for trigger-engine and view-model logic, and match the surrounding code's style.

## License

MIT — see [LICENSE](LICENSE).

---

<p align="center">
  <sub>Built with SwiftUI, SwiftData, and WeatherKit for iOS 26.</sub>
</p>
