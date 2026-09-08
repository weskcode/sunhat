# SunHat: marketing and pitch kit

Copy for launch. Everything between `---8<---` markers is ready to paste.

The core idea, in one sentence, is the thing to keep repeating: **most
reminder apps ask *when*; SunHat asks *what conditions*.** Every piece of copy
below is a different length of that same idea.

---

## 1. Pitches by length

### Six words

```
---8<---
Reminders that wait for the weather.
---8<---
```

### One line (App Store subtitle territory)

```
---8<---
Set a reminder for "when it's above 68°F and clear" and SunHat watches the forecast for you.
---8<---
```

### Elevator, ~30 seconds

```
---8<---
Calendar reminders assume you know when you'll want to do something. But a lot of plans don't work that way, you don't want to water the garden on Thursday, you want to water it when it hasn't rained in two days. You don't want to run at 6pm, you want to run when it's between 55 and 70 and not pouring.

SunHat lets you describe the conditions instead of the time. It watches the forecast in the background and notifies you the moment reality matches what you asked for. Seven trigger types, from a simple temperature range to combinations of temperature, humidity and wind.

No accounts, no sign-up. It's free, banner ads fund it, and a dollar a month removes them. Nothing else is gated.
---8<---
```

### The problem statement, for a deck

```
---8<---
Reminder apps have one input: time. That works when the constraint is your
schedule. It fails when the constraint is the world.

"Go for a run" at 6pm fires during a thunderstorm. "Water the garden" on
Thursday fires the morning after it rained. The reminder is technically
correct and practically useless, so people stop trusting it and turn it off.

SunHat changes the input from a timestamp to a condition, and does the
watching for you.
---8<---
```

---

## 2. Who it's for

Lead with the audience, not the feature. Each of these is a different opening
line for the same app.

| Audience | The hook | Trigger they'd set |
|---|---|---|
| **Gardeners** | Watering on a schedule wastes water and drowns plants | Dry period, 48 hours |
| **Runners and cyclists** | The weather decides whether the run happens | Temperature range + clear |
| **Photographers** | Golden hour is worthless if it's overcast | Above 68°F + sunny, evening |
| **Parents** | "Is today a park day?" answered before you're asked | Above 70°F, no rain |
| **Anyone with a grill** | The one weekend day worth cooking outside | Consecutive clear days |
| **Allergy sufferers** | Wind and dry stretches drive pollen | Composite: wind + dry period |

---

## 3. Social launch copy

### X / Twitter: launch post

```
---8<---
I built SunHat because my reminder app kept telling me to go running during thunderstorms.

Instead of "remind me at 6pm," you set "remind me when it's 55–70°F and clear." It watches the forecast and pings you when the weather actually cooperates.

Free on the App Store. No accounts.
---8<---
```

### X / Twitter: the feature thread opener

```
---8<---
Seven ways to describe a day in SunHat:

exact temperature
temperature range
sky conditions
feels-like
dry period
consecutive days
composite (temp + humidity + wind)

Pick one, describe the day you're waiting for, and stop checking the forecast yourself.
---8<---
```

### Mastodon / Bluesky

```
---8<---
Shipped SunHat today, a reminder app that waits for weather instead of a clock.

"Water the garden when it's been dry 48 hours." "Beach day when it's above 80 with no rain coming."

No accounts, no analytics SDK, full data export and deletion built in. Free with ads, $1/mo to remove them, nothing else gated.
---8<---
```

### Instagram / threads caption

```
---8<---
Your calendar doesn't know it's raining. ☔️

SunHat is a reminder app that waits for the right weather instead of the right time. Describe the day you're waiting for, it watches the forecast and tells you when it shows up.

Free on iPhone. Link in bio.
---8<---
```

---

## 4. Product Hunt

**Tagline** (60 char limit)

```
---8<---
Reminders that wait for the right weather, not the clock
---8<---
```

**First comment / maker's note**

```
---8<---
Hi Product Hunt 👋

SunHat came out of a small, dumb frustration: my reminder app told me to go running during a thunderstorm, because 6pm is 6pm regardless of what's happening outside.

A lot of plans are like that. Watering the garden. Photo walks. Beach days. Grilling. The constraint isn't your schedule, it's the weather, but every reminder app only takes a timestamp.

So SunHat takes conditions instead. You describe the day you're waiting for, like "55 to 70 and clear" or "dry for 48 hours," and it watches the forecast in the background and notifies you when reality matches.

Some things I care about that are worth calling out:

• It never invents weather. If the forecast isn't available, it says so. It will not show you a plausible-looking number it made up. There are tests guarding this.
• No accounts, no sign-up, no SunHat analytics SDK. Your location goes to the weather provider to fetch a forecast, and nowhere else.
• Full data export and one-tap deletion, built in rather than buried.
• Free, funded by banner ads on two screens. A dollar a month removes them. Nothing else is behind the subscription, no feature gates.

Built in SwiftUI with WeatherKit, iPhone-first. iPad, widgets and a watch app are next.

Happy to answer anything.
---8<---
```

---

## 5. Reddit (r/iosapps, r/apple, r/gardening)

Reddit punishes marketing language. Lead with the problem and be specific.

```
---8<---
I made a reminder app that waits for weather instead of time

The problem I had: every reminder app takes a timestamp. That's fine for "call the dentist," but useless for anything where the weather is the actual constraint. "Water the garden every Thursday" fires the morning after it rained. "Go for a run at 6" fires during a storm.

SunHat lets you set the condition instead. Temperature range, sky conditions, feels-like, dry period, consecutive days, or a combination of temperature + humidity + wind. It checks the forecast in the background and notifies you when the conditions actually show up.

A few implementation notes since this sub cares:
- WeatherKit for data. If a forecast isn't available the UI says so rather than filling in a plausible number.
- SwiftData locally, no server, no account.
- Notifications respect quiet hours and a daily cap so it can't spam you.
- Siri/Shortcuts and Spotlight support.
- Data export and deletion are real, not decorative.

Free with banner ads on two screens, $1/mo or $10/yr to remove them. Nothing else is gated, there's no pro tier.

iPhone only right now, iOS 26+. Happy to take feature requests.
---8<---
```

---

## 6. Short press release

```
---8<---
SunHat brings weather-triggered reminders to iPhone

SunHat, a new iPhone app, replaces the timestamp at the heart of every
reminder app with something more useful for outdoor plans: the weather
itself.

Instead of scheduling "go for a run" at a fixed time, SunHat users describe
the conditions they are waiting for, a temperature range, clear skies, a dry
stretch of days, and the app monitors the forecast in the background,
sending a notification when those conditions arrive.

The app supports seven trigger types, from a single temperature threshold to
composite conditions combining temperature, humidity and wind. It draws
forecast data from Apple WeatherKit and includes hourly forecasts,
temperature history, quiet hours, notification limits, Siri and Shortcuts
integration, and Spotlight search.

SunHat requires no account and collects no analytics of its own. Location
data is used to retrieve a forecast and for nothing else. Full data export
and deletion are built into the app.

SunHat is free on the App Store with banner advertising. An optional
subscription, SunHat Ad-Free, removes advertising for $1.00 per month or
$10.00 per year. No other features are restricted.

SunHat requires iOS 26 or later. Available now on the App Store.

Contact: weskcode@duck.com
---8<---
```

---

## 7. Objections, answered

Useful for support replies, review responses, and FAQ pages.

| Objection | Answer |
|---|---|
| "Why not just check the weather app?" | You can. SunHat is for the plans you'd otherwise forget to check for, the garden you meant to water, the photo walk you keep missing. It watches so you don't have to remember to. |
| "Why does it need my location?" | To fetch a forecast for where you are. You can skip it entirely and pick a city by hand. The coordinate goes to the weather provider and nowhere else. |
| "Ads in a weather app, really?" | On two screens, at the bottom, never covering a control. One dollar removes them permanently. Everything else is free, there's no pro tier hiding behind the subscription. |
| "Is my data being sold?" | No. There is no SunHat analytics SDK and no account to attach data to. The ad SDK is Google's and is disclosed in the privacy labels; the subscription turns it off entirely. |
| "Will it drain my battery?" | Background checks are rate-limited and coalesced. It should not appear near the top of your battery list, if it does, that's a bug worth reporting. |
| "Does it work without notifications?" | Yes, the Dashboard still shows what's ready. But notifications are the point, so it's worth allowing them. |

---

## 8. App icon and store assets

| Asset | Spec | Status |
|---|---|---|
| App icon | 1024 × 1024 PNG, no alpha, no rounded corners | In `Assets.xcassets` |
| App Store screenshots | See `APP_STORE_RELEASE_KIT.md` §4 | Capture required |
| App preview video | Optional, 15–30s, up to 3 per size | Not planned for 1.0 |

An app preview video is the single highest-leverage store asset after the
first two screenshots, but it is not required for 1.0 and a bad one is worse
than none. Skip it until the screenshots are settled.

---

## 9. Positioning against the alternatives

Do not name competitors in App Store metadata, Apple rejects it. This is for
your own copy, on your own site.

| | Apple Reminders | Weather apps | SunHat |
|---|---|---|---|
| Input | Time or place | Nothing, you read it | Weather conditions |
| Tells you when to act | On a schedule | No | When conditions match |
| Watches the forecast for you | No | You watch it | Yes |
| Needs an account | iCloud | Usually | No |

The honest framing: SunHat is not a replacement for either. It's the small
missing piece between them.
