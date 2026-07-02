# SunHat UI Polish Recommendations

## Scope

This pass keeps SunHat native SwiftUI and preserves the current tab, sheet, and detail navigation. The first implementation slice targets the daily-use surfaces:

- Dashboard
- All Tasks
- Reminder detail prediction card
- Shared product components

## Dashboard

Layout changes:
- Keep the current large weather card as the primary first-viewport object.
- Use shared `SunHatCardSection` chrome for "Ready Now", "Watching", and weather details so titles, subtitles, icons, actions, spacing, and glass treatment stay consistent.
- Replace plain explanatory copy in empty sections with `SunHatEmptyState` so empty states feel intentional and tappable areas remain visually calm.
- Remove unused root `GeometryReader` to reduce layout work.

Interaction changes:
- Weather card remains a button that expands details.
- "View All" remains a section action and opens the existing All Tasks sheet.
- Weather details use compact metric rows with accessible combined labels.

Animation specs:
- Dashboard reveal: `SunHatMotion.reveal`, 0.38s smooth, 16pt vertical offset. Reduce Motion uses 0.12s fade with no offset.
- Weather expand/collapse: `SunHatMotion.cardToggle`, 0.28s smooth. Reduce Motion uses 0.14s ease-in-out.
- Detail insertion: scale 0.96 plus opacity. Reduce Motion uses opacity only.
- Weather symbol bounce is disabled when Reduce Motion is enabled.

Accessibility:
- Weather card: combined label with location, temperature, feels-like value, and condition.
- Weather card value: "Details shown" or "Details hidden".
- Expand/collapse hint: tells VoiceOver users what double tap will do.
- Decorative weather and metric icons are hidden from accessibility.

## All Tasks

Layout changes:
- Keep active/inactive grouping and existing search/filter behavior.
- Use `SunHatEmptyState` for no tasks and no search results.
- Reminder rows use `SunHatStatusPill` instead of a color-only dot.
- Cards keep glass styling but use shared press feedback.

Interaction changes:
- Filter chips use the same motion policy as cards.
- Clear search button has an explicit accessibility label.
- Reminder cards remain `NavigationLink`s to existing detail views.

Animation specs:
- Filter changes: `SunHatMotion.cardToggle`, 0.28s smooth. Reduce Motion uses 0.14s ease-in-out.
- Scroll transitions remain subtle opacity/scale and skip scale when Reduce Motion is enabled.
- Press feedback: `SunHatMotion.press`, 0.16s smooth scale to 0.985 and opacity to 0.86. Reduce Motion keeps opacity only.

Accessibility:
- Filter chips expose selected/not-selected values and selected traits.
- Reminder cards combine title, status, description, and trigger condition into a single label.
- Reminder cards include the hint "Opens task details."
- Status is text plus symbol, not color alone.

## Reminder Detail Prediction

Layout changes:
- Confidence is shown as a status pill beside the prediction text.
- Progress bar remains lightweight SwiftUI shapes.
- Matching-day dots remain visual support, with the full value exposed to accessibility.

Animation specs:
- Confidence progress width animates with `SunHatMotion.cardToggle`.
- Reduce Motion uses the short ease-in-out fallback.

Accessibility:
- Prediction card label: "Next trigger" plus prediction description.
- Prediction card value: confidence text plus matching-day count.
- Decorative progress bar is hidden from accessibility.

## Shared Components

Added:
- `SunHatPressButtonStyle`
- `SunHatCardSection`
- `SunHatStatusPill`
- `SunHatEmptyState`

Design rules:
- Prefer system text styles through `AppFontStyle`.
- Keep glass surfaces at 12-20pt radius depending on hierarchy.
- Use icons as visual anchors, but hide decorative symbols from VoiceOver.
- Avoid unmanaged repeating animation in product components.
- Route every animation through `SunHatMotion` unless it is a system transition with its own accessibility behavior.
