# Privacy Policy

**Effective date: September 8, 2026**

SunHat is a weather-triggered reminder app for iPhone. This policy explains
what data the app handles, what leaves your device, and what you can do
about it.

The short version: SunHat has no accounts and no servers. Your reminders,
preferences and cached weather stay on your iPhone. The only data that
leaves your device is the coordinate sent to a weather provider to fetch a
forecast. In the free, ad-supported version, it also includes the data Google's
advertising SDK collects to serve and measure ads.

---

## Who we are

SunHat is developed by Wesley Keetch, an independent developer.

Contact: **weskcode@duck.com**

## We have no account system and no backend

SunHat does not ask you to sign up, sign in, or provide an email address.
There is no SunHat server that receives your data, because there is no SunHat
server. Nothing you create in the app is transmitted to us, and we could not
retrieve it if we wanted to.

## Data stored on your device

The following is stored locally on your iPhone using Apple's SwiftData
framework, and never sent to us:

- **Reminders you create**: titles, notes, icons, colors, and the weather
  conditions you chose
- **App preferences**: units, quiet hours, notification limits, appearance
- **Cached weather data**: recent forecasts, so the app works offline and
  makes fewer network requests
- **Saved locations**: any city you pick manually

This data is included in your device backup if you back up your iPhone to
iCloud or a computer. That backup is governed by Apple's privacy policy, not
this one.

## Location

If you grant location permission, SunHat uses your coordinates to fetch a
weather forecast for where you are.

- Your coordinate is sent **to the weather provider only** (Apple WeatherKit),
  for the sole purpose of retrieving a forecast.
- It is not sent to us, not stored on any server we control, and not used to
  build a profile of your movements.
- Location permission is **optional**. You can decline it and pick a city
  manually instead; the app works either way.
- You can grant reduced (approximate) accuracy in iOS Settings. SunHat will
  use it, though forecasts will be less specific to your exact area.
- You can revoke location access at any time in **iOS Settings → Privacy &
  Security → Location Services → SunHat**.

## Notifications

If you allow notifications, SunHat sends them locally from your device when
your conditions are met. Notifications are scheduled and delivered on-device
through iOS. No push server is involved, and no notification content is
transmitted anywhere.

## Weather data

Weather is provided by **Apple WeatherKit**. Apple receives the location
coordinate needed to answer the forecast request. Apple's handling of that
request is governed by Apple's privacy policy:
<https://www.apple.com/legal/privacy/>

SunHat does not fabricate weather data. When a forecast is unavailable, the
app says so rather than displaying an estimated value.

## Advertising (free version only)

The free version of SunHat displays banner advertisements supplied by
**Google AdMob**, on the Dashboard and Weather screens only.

To serve and measure those ads, Google's SDK may collect:

- Your device's **advertising identifier (IDFA)**, if you permit tracking
- **Advertising data**: ad impressions, clicks, and related interaction
- **Coarse location, device and app information, and diagnostic data**, as
  described in Google's own documentation

This data is collected by Google, not by us. We do not receive it, and we
have no access to it beyond aggregate revenue reporting. Google's handling
is governed by Google's privacy policy:
<https://policies.google.com/privacy>

### App Tracking Transparency

Before any cross-app tracking occurs, iOS asks for your permission through
Apple's App Tracking Transparency prompt. SunHat does not show this prompt on
your first session. It waits until you have had a chance to use the app.

**If you decline, nothing in the app stops working.** Ads simply become
non-personalized.

You can change this at any time in **iOS Settings → Privacy & Security →
Tracking**.

### Consent in the EEA, UK and Switzerland

If you are in a region covered by the GDPR or equivalent rules, SunHat
presents Google's certified consent form before any ad request is made. If
you have not consented, no ad request is sent. You can reopen the consent
form and change your choice at any time from **Settings → Privacy → Ad
Privacy Options** inside the app.

### Removing ads entirely

The optional **SunHat Ad-Free** subscription removes all advertising. When
the subscription is active, the advertising SDK makes no ad requests at all.

## Subscriptions and payment

SunHat Ad-Free is an auto-renewable subscription sold through Apple's App
Store.

- **We never see your payment details.** Apple processes the transaction; we
  receive only an anonymous receipt confirming that a subscription is active.
- We do not receive your name, email address, billing address, or card
  information.
- Manage or cancel your subscription in **iOS Settings → your name →
  Subscriptions**, or in the App Store app.

Apple's handling of your purchase is governed by Apple's privacy policy.

## Analytics

SunHat contains no analytics SDK of its own. We do not track which screens
you visit, which features you use, how often you open the app, or what your
reminders say.

Apple provides aggregate, anonymized App Store metrics (downloads, crash
counts) that cannot be tied to an individual. Google provides aggregate ad
performance reporting. Neither identifies you to us.

## Your rights and controls

Because your data is on your device, you control it directly:

| What you want | Where |
|---|---|
| Export everything SunHat holds | Settings → Privacy → Export My Data |
| Delete everything, permanently | Settings → Privacy → Delete All Data |
| Turn location off | iOS Settings → Privacy & Security → Location Services |
| Turn off ad tracking | iOS Settings → Privacy & Security → Tracking |
| Change ad consent (EEA/UK) | Settings → Privacy → Ad Privacy Options |
| Remove ads entirely | Settings → SunHat Ad-Free |
| Remove all data at once | Delete the app |

Deleting the app removes all locally stored data. Deletion is immediate and
irreversible; we hold no copy to restore from.

If you are covered by the **GDPR**, your rights of access, rectification,
erasure, restriction, portability and objection are satisfied by the export
and delete controls above, since we hold no personal data about you on any
system we operate. Our lawful basis for processing location is your consent,
which you may withdraw at any time by revoking the permission.

If you are covered by the **CCPA/CPRA**, note that we do not sell or share
personal information as those terms are defined. The advertising identifier
handled by Google in the free version may constitute "sharing" for
cross-context behavioral advertising under some interpretations; declining
App Tracking Transparency, or subscribing to SunHat Ad-Free, prevents it.

## Children

SunHat is not directed to children under 13, and we do not knowingly collect
personal information from them. The app is not submitted to the App Store's
Kids Category, because the Kids Category prohibits the third-party
advertising the free version relies on.

## International transfers

We operate no servers, so we transfer nothing internationally. Apple and
Google may process data in countries other than yours, as described in their
respective privacy policies.

## Data retention

We retain nothing, because we receive nothing. Data on your device persists
until you delete it or remove the app. Apple and Google apply their own
retention periods to the data they collect.

## Security

Data on your device is protected by iOS file-system encryption and your
device passcode. All network requests use HTTPS. Because there is no account
and no server, there is no credential to steal and no central database to
breach.

## Changes to this policy

If this policy changes materially, the updated version will be posted here
with a new effective date, and the in-app policy will be updated to match. If
a change expands what is collected, it will be described in the release notes
for the version that introduces it.

## Contact

Questions about this policy, or about your data:

**weskcode@duck.com**
