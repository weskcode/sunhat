# SunHat Native iOS Feature Progress

Updated: July 2, 2026

## Implemented in Source

- App Intents and App Shortcuts for opening sections, creating a weather reminder, checking today's reminders, showing the next ready reminder, and opening notification settings.
- Intent handoff into `MainTabView`, including direct opening of the create-reminder sheet.
- Central notification category/action registry with native actions: View Forecast, Snooze 2h, Pause This Reminder, and Mark Done.
- Notification delegate routing at app launch so notification action taps reach `TriggerNotificationManager`.
- SwiftData-backed notification action handling for complete, snooze, and pause.
- Core Spotlight indexing for reminders and saved locations, with search-result routing back into the app.
- `SunHatMotion` animation utility and a lightweight `WeatherConditionLayer` for subtle SwiftUI Canvas weather motion.
- Dashboard/reminder-card animation polish using shared motion, numeric content transitions, scroll transitions, and Reduce Motion fallbacks.
- Onboarding and celebration animation cleanup for deterministic Reduced Motion behavior and lower idle animation cost.

## Already Present

- WeatherKit is already the preferred native provider, with OpenWeatherMap as fallback.
- Widget planning exists in `WIDGET_SETUP.md`, including the required `SunHatKit` extraction and widget target setup.

## Requires Physical Device Validation

- Background notification delivery after BGTaskScheduler wakes the app.
- WeatherKit entitlement provisioning on the release App ID.
- Notification action behavior from the lock screen and Notification Center, especially Pause This Reminder and Snooze 2h.
- Spotlight indexing visibility in system search after creating/editing/deleting reminders and saved locations.
- First-launch permission timing on a clean physical device. Simulator state retained a queued notification prompt during local verification, but source inspection confirms startup configuration now registers notification categories without calling `requestAuthorization`.

## Deferred Until Target/Capability Work

- WidgetKit: do not hand-edit the synchronized-group `.pbxproj` target graph. Create `SunHatKit` and `SunHatWidget` targets in Xcode first, then source implementation can continue safely.
- Live Activities: keep deferred unless SunHat models a short-lived event such as "rain expected in 34 minutes" or "temperature threshold approaching." Passive long-term reminders are not a good Live Activity fit.

## July 2, 2026 Local Verification

- `plutil -lint SunHat/Info.plist SunHat/PrivacyInfo.xcprivacy SunHat/SunHat.entitlements` passed.
- `git diff --check -- '*.swift' '*.plist' '*.entitlements' '*.md' '*.txt' '*.py' '.gitignore'` passed.
- Source scan found no `remote-notification`, `aps-environment`, stale `cloud.slash.fill`, `withCheckedContinuation`, or startup remote-notification registration references in live app source.
- `xcodebuild -project SunHat.xcodeproj -scheme SunHat -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/SunHatReleaseVerifyGenericBFT COMPILER_INDEX_STORE_ENABLE=NO build-for-testing` passed. The only warning was App Intents metadata extraction on the UI test bundle.
- `xcodebuild test-without-building ... -only-testing:SunHatTests` did not reach test discovery and was stopped after the simulator runner stalled. This matches the existing local CoreSimulator/Xcode runner instability noted in the audit docs; test bundles still compiled successfully.
