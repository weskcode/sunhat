# Contributing to SunHat

Thanks for your interest. SunHat is a small, deliberately focused app, and the fastest way to get a change merged is to understand what it's trying to be.

## The one-sentence scope

> Describe weather conditions → SunHat watches the forecast → you get notified when they're met.

Changes that sharpen that loop are welcome. Changes that add a second, unrelated purpose to the app probably aren't — SunHat is not trying to become a general weather app or a general to-do app, and both temptations come up often.

If you're unsure whether an idea fits, open an issue before writing code.

## Non-negotiables

These aren't style preferences; breaking them is a correctness bug and the change will be sent back.

**Never fabricate weather data.** If a provider returns no hourly forecast, the UI shows an unavailable state. If there isn't enough stored history for a comparison, it says "Not enough history yet." No sine waves, no interpolation, no seasonal constants standing in for real data. Users make real plans from this screen.

**Never imply official authority.** Threshold-based notices are branded "SunHat … Advisory" and state the threshold that produced them. Nothing in the app may resemble a government or WeatherKit severe-weather warning.

**Privacy deletions must be complete.** If you persist anything new — SwiftData, `UserDefaults`, files — wire it into the deletion path in `DataPrivacyViewModel`. There is a schema-parity test guarding this; keep it passing.

**Controls must actually work.** A toggle that doesn't persist or a screen that does nothing gets deleted, not shipped. An entire settings screen was removed for this reason.

## Before you open a PR

1. **Build cleanly.** Zero warnings.
   ```bash
   xcodebuild -scheme SunHat -configuration Debug -destination 'generic/platform=iOS Simulator' build
   ```
2. **Tests pass.**
   ```bash
   xcodebuild -scheme SunHat -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SunHatTests test
   ```
3. **Add tests for logic.** Trigger-engine changes and view-model behavior need coverage. UI-only tweaks don't.
4. **Check both appearances.** Light and dark, and Dynamic Type at accessibility sizes if you touched layout.

## Where things live

| Area | Path | Notes |
|---|---|---|
| Trigger evaluation | `Services/Trigger/` | Core logic. Most correctness-sensitive code in the project. Always test changes here. |
| Weather providers | `Services/Weather/` | Behind `WeatherProviding`. Real data only. |
| Persistence | `Models/` | SwiftData `@Model` types. New types must join `SunHatModelSchema` **and** the deletion path. |
| Presentation state | `ViewModels/` | `@Observable` for new code. |
| UI | `Views/` | Grouped by feature. |

## Code style

Match the surrounding code — it's consistent, and consistency beats personal preference.

- **Concurrency:** `async`/`await` only. No completion handlers in new code. `@MainActor` for UI-bound types.
- **Observation:** `@Observable` for new view models. Some older ones are still `ObservableObject` + Combine; migrating one is a welcome standalone PR.
- **Dependencies:** inject through the existing protocol seams (`WeatherProviding`, `LocationManaging`, `SettingsOpening`, `NotificationPermissionProviding`) rather than reaching for singletons. This is what makes the view models testable.
- **Design:** iOS 26 Liquid Glass. `.glassEffect()` on card surfaces, `Color(.systemBackground)` for page backgrounds. Don't nest glass in glass.
- **Motion:** every animation respects `accessibilityReduceMotion`.
- **Comments:** explain *why*, not *what*. The non-obvious constraint, the bug this guards against, the reason it isn't the simpler thing.
- **No third-party dependencies.** Apple frameworks only. This is intentional.

## Commit messages

Describe the behavior change and why it matters:

```
Fix dry-period evaluation across the full forecast window

24/48h "no precipitation" checks sampled only current conditions, so a
reminder could fire with rain forecast later in the window. Now evaluates
every forecast day covering the period and requires full coverage.
```

## Reporting bugs

Include the iOS version, device or simulator, and steps to reproduce. For weather or trigger issues, Console.app logs under subsystem `org.wesley.sunhat` are extremely helpful — particularly category `AppleWeatherKitAPI` for fetch failures, which surface provisioning problems that otherwise look like generic network errors.

## Good first contributions

- Migrate one `ObservableObject` view model to `@Observable`
- Replace `UIImpactFeedbackGenerator` / `UINotificationFeedbackGenerator` call sites with `.sensoryFeedback`
- Extract user-facing strings into a String Catalog (none exists yet — all copy is inline English)
- Split one of the remaining 600+ line views into focused subviews
- VoiceOver labels for weather cards, forecast charts, and trigger indicators
