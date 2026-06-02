# SunHat Typography Plan

## Current Direction

SunHat should use Apple system typography by default. This keeps the app aligned with HIG, improves Dynamic Type behavior, avoids custom font asset overhead, and gives the interface a more native iOS feel.

The previous Inter customization plan is retired. Do not add Inter font files, `UIAppFonts`, or app-wide custom font registration unless a future brand pass explicitly requires it.

## Completed

- [x] Removed the global Inter implementation from `SunHat/Utilities/Theme/FontTheme.swift`.
- [x] Kept existing `AppFont` and `AppFontStyle` APIs as compatibility wrappers so call sites do not need a risky mass rewrite.
- [x] Updated `AppFont.inter(size:weight:)` and `UIFont.inter(size:weight:)` to return system fonts.
- [x] Updated `AppFontStyle` to use semantic SwiftUI text styles and preferred UIKit text styles.
- [x] Removed explicit `SF Pro Display` custom font calls from onboarding and location permission screens.
- [x] Verified no Swift source contains `Inter-`, `UIFont(name:)`, or `.custom("SF Pro Display"...`.

## Current Implementation

Use semantic system styles whenever possible:

```swift
Text("Ready Now")
    .font(.headline)

Text("Create your first weather-triggered task.")
    .font(.body)
    .foregroundStyle(.secondary)
```

Use the compatibility wrappers only where the existing code already depends on them:

```swift
Text("Temperature")
    .font(AppFontStyle.title3.font)

Image(systemName: "sun.max.fill")
    .font(AppFont.inter(size: 44, weight: .regular))
```

The wrappers should continue to resolve to system fonts, not custom font files.

## Circle Back

- [ ] Rename `AppFont.inter` to a neutral name such as `AppFont.system` after a broader call-site cleanup.
- [ ] Prefer direct semantic styles (`.headline`, `.body`, `.caption`) in new code instead of adding more wrapper usage.
- [ ] Audit large custom-size system fonts on dashboard/weather screens for Dynamic Type behavior.
- [ ] Verify onboarding, dashboard, reminders, settings, and weather screens through accessibility Dynamic Type sizes.
- [ ] Keep any future custom brand typography limited to intentional brand moments, not dense app surfaces.

## Testing Checklist

- [x] Unit test build passed through `SunHatTests` on June 2, 2026: `131 passed, 0 failed`.
- [ ] Visual QA all major screens at default Dynamic Type.
- [ ] Visual QA all major screens at accessibility Dynamic Type.
- [ ] Confirm no text clips in buttons, empty states, compact reminder surfaces, or reminder rows.
