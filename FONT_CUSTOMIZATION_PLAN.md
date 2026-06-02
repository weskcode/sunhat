# Font Customization Plan for SunHat

## Overview
Change the app-wide font from system default (SF Pro) to a custom clean sans-serif font.

## Recommended Font: **Inter**

**Why Inter?**
- Clean, modern, highly legible
- Excellent for UI/text-heavy apps
- Supports full weight spectrum (Thin to Black)
- Variable font available for optimal performance
- Professional look that pairs well with iOS Liquid Glass design

## Alternative Options
| Font | Style | Best For |
|------|-------|----------|
| **Inter** (recommended) | Clean, neutral | General app use |
| **Poppins** | Rounded, friendly | Onboarding, casual |
| **Montserrat** | Geometric, elegant | Weather dashboards |
| **Nunito** | Soft, rounded | Friendly reminders |
| **DM Sans** | Modern, geometric | Settings, technical |

---

## Implementation Steps

### Phase 1: Add Font Files

1. **Download Inter font family**
   - Get from: https://github.com/rsms/inter/releases
   - Required weights: Regular, Medium, Semibold, Bold (minimum)
   - Full set: Thin, Light, Regular, Medium, Semibold, Bold, Black

2. **Add fonts to Xcode project**
   ```
   SunHat/Resources/Fonts/
   ├── Inter-Thin.ttf
   ├── Inter-Light.ttf
   ├── Inter-Regular.ttf
   ├── Inter-Medium.ttf
   ├── Inter-Semibold.ttf
   ├── Inter-Bold.ttf
   └── Inter-Black.ttf
   ```

3. **Add to project via Xcode**
   - File → Add Files to "SunHat" → Select all .ttf files
   - Check "Copy items if needed"
   - Select all targets (SunHat)

4. **Register fonts in Info.plist**
   ```xml
   <key>UIAppFonts</key>
   <array>
       <string>Inter-Thin.ttf</string>
       <string>Inter-Light.ttf</string>
       <string>Inter-Regular.ttf</string>
       <string>Inter-Medium.ttf</string>
       <string>Inter-Semibold.ttf</string>
       <string>Inter-Bold.ttf</string>
       <string>Inter-Black.ttf</string>
   </array>
   ```

### Phase 2: Create Font System

Create `SunHat/Utilities/Theme/FontTheme.swift`:

```swift
import SwiftUI

enum AppFont {
    static func inter(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let fontName: String
        switch weight {
        case .thin:        fontName = "Inter-Thin"
        case .light:       fontName = "Inter-Light"
        case .regular:     fontName = "Inter-Regular"
        case .medium:      fontName = "Inter-Medium"
        case .semibold:    fontName = "Inter-Semibold"
        case .bold:        fontName = "Inter-Bold"
        case .black:       fontName = "Inter-Black"
        default:           fontName = "Inter-Regular"
        }
        return .custom(fontName, size: size)
    }
}

extension View {
    func appFont(_ style: AppFontStyle) -> some View {
        self.font(style.font)
    }
}

enum AppFontStyle {
    case largeTitle
    case title
    case title2
    case title3
    case headline
    case body
    case callout
    case subheadline
    case footnote
    case caption
    case caption2
    
    var font: Font {
        let size: CGFloat
        let weight: Font.Weight
        
        switch self {
        case .largeTitle:  size = 34; weight = .bold
        case .title:       size = 28; weight = .bold
        case .title2:      size = 22; weight = .bold
        case .title3:      size = 20; weight = .semibold
        case .headline:    size = 17; weight = .semibold
        case .body:        size = 17; weight = .regular
        case .callout:     size = 16; weight = .regular
        case .subheadline: size = 15; weight = .regular
        case .footnote:    size = 13; weight = .regular
        case .caption:     size = 12; weight = .regular
        case .caption2:    size = 11; weight = .regular
        }
        
        return AppFont.inter(size: size, weight: weight)
    }
}
```

### Phase 3: Apply Font System App-Wide

**Option A: Environment Modifier (Recommended)**

Create `SunHat/Utilities/Theme/FontEnvironment.swift`:

```swift
import SwiftUI

struct FontEnvironment: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.body) // Default
    }
}

extension View {
    func applyAppFonts() -> some View {
        self.modifier(FontEnvironment())
    }
}
```

**Option B: Use font extension directly**

Replace patterns like:
```swift
.font(.headline)
```

With:
```swift
.font(AppFontStyle.headline)
```

### Phase 4: Migrate Existing Fonts

Replace all 795 font occurrences. Key files to update:

| Priority | File | Impact |
|----------|------|--------|
| High | `Views/Dashboard/DashboardView.swift` | Main screen |
| High | `Views/Weather/WeatherView.swift` | Weather display |
| High | `Views/Reminders/DetailedReminderView.swift` | Reminder details |
| High | `Views/Onboarding/WelcomeView.swift` | First impression |
| High | `Views/Onboarding/UserPreferencesOnboardingView.swift` | Onboarding |
| Medium | `Views/Reminders/AllRemindersView.swift` | Reminder list |
| Medium | `Views/Reminders/ReminderManagementView.swift` | Management |
| Medium | `Views/Settings/SettingsView.swift` | Settings |
| Medium | `Views/Location/LocationManagementView.swift` | Locations |
| Low | All component files | Reusable UI |

**Search/replace patterns:**
- `.font(.headline)` → `.font(AppFontStyle.headline)`
- `.font(.body)` → `.font(AppFontStyle.body)`
- `.font(.title)` → `.font(AppFontStyle.title)`
- `.font(.title2)` → `.font(AppFontStyle.title2)`
- `.font(.title3)` → `.font(AppFontStyle.title3)`
- `.font(.caption)` → `.font(AppFontStyle.caption)`
- `.font(.caption2)` → `.font(AppFontStyle.caption2)`
- `.font(.subheadline)` → `.font(AppFontStyle.subheadline)`
- `.font(.callout)` → `.font(AppFontStyle.callout)`
- `.font(.footnote)` → `.font(AppFontStyle.footnote)`

**System font with custom size:**
- `.font(.system(size: X))` → `AppFont.inter(size: X, weight: .regular)`
- `.font(.system(size: X, weight: W))` → `AppFont.inter(size: X, weight: W)`
- `.font(.system(size: X, weight: W, design: .rounded))` → `AppFont.inter(size: X, weight: W)` (remove rounded)

### Phase 5: Testing

1. Build project: `xcodebuild -scheme SunHat -configuration Debug build`
2. Test all screens for font rendering
3. Verify Dynamic Type support (accessibility)
4. Test on simulator and device

---

## File Changes Summary

| Action | File |
|--------|------|
| Create | `SunHat/Resources/Fonts/` (folder with .ttf files) |
| Modify | `SunHat/Info.plist` (add UIAppFonts) |
| Create | `SunHat/Utilities/Theme/FontTheme.swift` |
| Modify | All ~20+ view files with font updates |

---

## Time Estimate

- **Font setup**: 10 min
- **FontTheme.swift creation**: 15 min
- **Migration (bulk replace)**: 30-45 min
- **Testing**: 15 min
- **Total**: ~1.5 hours
