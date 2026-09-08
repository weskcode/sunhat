# SunHat: TestFlight release guide

What to fill into App Store Connect's TestFlight tab, the message to send
testers, and the sequence for getting a build up.

---

## 1. Beta App Information (set once)

| Field | Value |
|---|---|
| **Beta App Description** | see block below |
| **Feedback Email** | `weskcode@duck.com` |
| **Marketing URL** | `https://sunhat.apphq.online` |
| **Privacy Policy URL** | `https://sunhat.apphq.online/privacy` |
| **Sign-in required** | No |
| **Demo account** | Not applicable |

### Beta App Description

```
---8<---
SunHat is a weather-triggered reminder app. Instead of "remind me at 5pm," you set "remind me when it's above 68°F and clear," and SunHat watches the forecast and tells you when conditions match.

This build is feature-complete for 1.0. The free tier shows banner ads; an optional subscription removes them. Ads and purchases run against test servers in TestFlight, so nothing is charged and no real ad revenue is involved.

No account or sign-up. Location and notifications are both optional, though the app is much more useful with them on.
---8<---
```

---

## 2. What to Test: send this to testers

Paste into the **What to Test** field for the build (4000 char limit).

```
---8<---
Thanks for testing SunHat. This is the 1.0 candidate, feature-complete, and I'm looking for anything broken, confusing, or ugly before it goes to the App Store.

WHAT SUNHAT DOES
Set a reminder that waits for weather instead of a clock. "Water the garden when it's been dry 48 hours." "Run when it's 55-70°F and clear." SunHat watches the forecast and notifies you when reality matches.

═══ THE 5-MINUTE PASS ═══

1. ONBOARDING
   Go through the first-run flow. Allow location and notifications when asked.
   → Did anything feel like it asked for too much, too early?

2. MAKE ONE THAT FIRES NOW
   Tap + in the tab bar. Set a temperature range that matches your actual
   weather right now, so it triggers immediately.
   → Did the reminder appear as "ready" on the Dashboard?
   → Did you get a notification?

3. MAKE ONE THAT WAITS
   Create a second one for conditions that are days away.
   → Does the Weather tab's prediction card show a sensible confidence?

4. LOOK AROUND
   Visit all four tabs. Check the hourly forecast and the temperature
   history charts.
   → Any number that looks made up or obviously wrong?

═══ WHAT I MOST NEED EYES ON ═══

• NOTIFICATIONS ACTUALLY ARRIVING. This is the whole product. Leave a
  reminder set overnight and tell me if it fired when it should have, or
  fired when it shouldn't have.

• ACCURACY. SunHat should never invent weather. If a forecast isn't
  available it's supposed to say so, not show a plausible-looking number.
  If you ever see a temperature you don't believe, screenshot it.

• THE ADS. Banners appear at the bottom of the Dashboard and Weather tabs
  only. They should never cover a button, never shift the layout as they
  load, and never appear on other screens.
  → Did a banner ever get in your way or push content around?

• THE SUBSCRIPTION. Settings > SunHat Ad-Free > Get Ad-Free. In TestFlight
  this uses Apple's sandbox, so YOU WILL NOT BE CHARGED.
  → Buy either plan. Do the ads disappear immediately?
  → Force-quit and reopen. Still ad-free?
  → Try Restore Purchases.
  → Try switching monthly ↔ annual.

• DARK MODE AND BIG TEXT. Settings > Display & Brightness > Dark, and
  Accessibility > Display & Text Size > Larger Text, cranked to maximum.
  → Any text cut off, overlapping, or unreadable?

• VOICEOVER, if you use it. I especially want to know about unlabeled
  buttons.

• BATTERY. Check Settings > Battery after a day. SunHat does background
  weather checks and shouldn't be near the top of that list.

═══ ALSO WORTH POKING ═══

• Siri: "Hey Siri, create a SunHat reminder"
• Spotlight: swipe down, search for a reminder you made
• Manual city: Weather tab > location button, pick somewhere else
• Quiet hours: Settings > Notifications
• Airplane mode: does it degrade gracefully or show a confusing error?
• Settings > Privacy > Export My Data, and Delete All Data

═══ KNOWN AND EXPECTED ═══

• Ads are Google's TEST ads, placeholder creative, not real inventory.
• Purchases are sandbox. Nothing is charged. Sandbox subscriptions renew
  on an accelerated clock, so a "monthly" plan may renew every few minutes.
• iPad works but is not optimized, it's an iPhone layout scaled up.
  iPad, widgets and a watch app are planned after 1.0.
• Spanish is supported. If your device is in Spanish and something reads
  awkwardly, tell me.

═══ HOW TO REPORT ═══

Screenshot the problem, then use TestFlight's built-in feedback (shake the
device, or the Send Beta Feedback button). Tell me what you expected and
what happened. "This felt weird" is genuinely useful, I want to hear about
confusing as much as broken.
---8<---
```

---

## 3. Build and upload sequence

TestFlight uploads need your Apple ID and an App Store Connect app record;
they cannot be automated from this repo without your credentials.

### One-time setup

1. Create the app record in App Store Connect with bundle ID
   `org.wesley.sunhat`.
2. Confirm the App ID has the **WeatherKit** capability, plus Push
   Notifications and Background Modes.
3. Sign the Paid Applications agreement (required before subscriptions work
   at all, even in sandbox).

### Per build

The Archive and Distribute Xcode Cloud workflow uploads to TestFlight
automatically on every archive; see
[`XCODE_CLOUD_SETUP.md`](XCODE_CLOUD_SETUP.md) for the one-time setup.

For a manual local archive instead:

```bash
xcodebuild -scheme SunHat -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/SunHat.xcarchive archive
```

Then Xcode → Window → Organizer → Distribute App → TestFlight & App Store.
Or use `xcodebuild -exportArchive` with an `ExportOptions.plist` once you
have a distribution certificate.

Build numbers: a Release-only build phase reads `buildnumber.txt`,
increments it, and writes the result into the built product's
`CFBundleVersion`. `buildnumber.txt` is gitignored and local to your
machine. Every upload needs a unique build number against the same
`MARKETING_VERSION`, if an upload is rejected as a duplicate, bump the
file and archive again.

### Export compliance

`ITSAppUsesNonExemptEncryption = false` is already in `Info.plist`, so
TestFlight won't ask on each upload.

---

## 4. Tester groups

| Group | Who | Notes |
|---|---|---|
| **Internal** | Your own devices | Up to 100 testers, no review, available in minutes |
| **External, Friends** | Invited by email | Needs Beta App Review on the first build of each version |

External TestFlight builds go through a lighter review than App Store
submission, but the same rules apply: working URLs, accurate description,
and no placeholder content.

---

## 5. Before promoting a TestFlight build to the App Store

- [ ] Swap the 3 AdMob test IDs for real ones
      (`docs/MONETIZATION_GOLIVE.md` §1)
- [ ] Populate `NSPrivacyTrackingDomains`
- [ ] Create both subscription products in App Store Connect with `en` + `es`
      metadata and paywall review screenshots
- [ ] Verify the purchase loop against the real sandbox once: ads visible →
      buy → ads gone → relaunch still ad-free → reinstall → Restore works
- [ ] Capture 6.9" screenshots on an iPhone 17 Pro Max
- [ ] Full checklist: `docs/APP_STORE_RELEASE_KIT.md` §9
