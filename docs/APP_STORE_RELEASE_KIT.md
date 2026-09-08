# SunHat 1.0: App Store release kit

Everything App Store Connect asks for, in the order it asks. Every block
between `---8<---` markers is meant to be copied verbatim into the matching
field. Character counts are validated against Apple's limits.

Written for the 1.0 submission. Bundle ID `org.wesley.sunhat`.

**Companion docs**
- [`MARKETING_KIT.md`](MARKETING_KIT.md): pitches, social copy, Product Hunt,
  press release, objection handling
- [`TESTFLIGHT_RELEASE.md`](TESTFLIGHT_RELEASE.md): beta metadata, the What
  to Test message, archive and upload steps
- [`XCODE_CLOUD_SETUP.md`](XCODE_CLOUD_SETUP.md): CI and TestFlight
  distribution setup, replacing the old GitHub Actions workflow
- [`MONETIZATION_GOLIVE.md`](MONETIZATION_GOLIVE.md): every test value that
  must be swapped for a live one, and where it lives
- [`PRIVACY_POLICY.md`](PRIVACY_POLICY.md) and [`TERMS_OF_USE.md`](TERMS_OF_USE.md):
  the source text for the two hosted legal pages, kept here so the app repo
  and the live site can't drift apart unnoticed

---

## 1. App information (set once, not per-version)

| Field | Value |
|---|---|
| **Name** | `SunHat: Weather Reminders` (25/30) |
| **Subtitle** | `Forecast alerts for your plans` (30/30) |
| **Bundle ID** | `org.wesley.sunhat` |
| **SKU** | `SUNHAT-IOS-001` |
| **Primary category** | Weather |
| **Secondary category** | Productivity |
| **Primary language** | English (U.S.) |
| **Additional localization** | Spanish (Mexico), the app ships `en` + `es` |
| **Age rating** | 4+ |
| **Copyright** | `2026 Wesley Keetch` |
| **Price** | Free (with In-App Purchases) |
| **Availability** | All territories |

### Age rating questionnaire

Answer **None** to every content category. The two that need care:

| Question | Answer | Why |
|---|---|---|
| Does your app contain, show, or access third-party advertising? | **Yes** | Google AdMob banners in the free tier |
| Is this app for kids (Kids Category)? | **No** | Do not opt in, the Kids Category forbids third-party ads and ATT |
| Unrestricted web access | **No** | No in-app browser |
| Gambling / contests | **No** | |

Result: **4+**.

### URLs

| Field | Value | Required? |
|---|---|---|
| Support URL | `https://sunhat.apphq.online` | Required |
| Marketing URL | `https://sunhat.apphq.online` | Optional |
| Privacy Policy URL | `https://sunhat.apphq.online/privacy` | Required |
| Terms of Use (EULA) | `https://sunhat.apphq.online/terms` | **Required, auto-renewable subscription** |

There is no dedicated `/support` page on the site, so the Support URL field
uses the homepage, which lists a contact email in its footer. That satisfies
Apple's requirement (a working page where a user can reach you), but a real
support page with an FAQ is worth adding later.

> Apple rejects subscription apps whose Privacy Policy and Terms URLs 404 or
> don't describe the subscription. Verify both resolve before submitting.

**Two things to fix on the live site before submitting, neither of them
code changes:**
1. `/privacy` is live and correct. `/terms` does not exist yet.
   [`TERMS_OF_USE.md`](TERMS_OF_USE.md) in this repo is ready to publish
   there as-is.
2. The homepage footer still shows an old contact address. It should read
   `weskcode@duck.com` to match the privacy policy, the terms, and the app
   itself.

---

## 2. Version information (per-release)

### Promotional text: 153/170

Editable without a new build. Use it for seasonal hooks.

```
---8<---
Set a reminder for "when it's above 68°F and clear" and SunHat watches the forecast for you. No accounts, no sign-up. Free with ads, go ad-free anytime.
---8<---
```

### Description: 2467/4000

```
---8<---
Most reminder apps ask when. SunHat asks what conditions.

A calendar reminder for "go for a run" fires whether it's sunny or sleeting. But some plans don't depend on the clock, they depend on the weather. SunHat lets you describe the conditions you're waiting for, then watches the forecast and tells you the moment reality matches.

SET IT AND FORGET IT

• "Go for a run when it's 55–70°F and clear"
• "Water the garden when it's been dry for 48 hours"
• "Beach day when it's above 80°F with no rain coming"
• "Golden hour photo walk when it's above 68°F and sunny"

SEVEN WAYS TO DESCRIBE A DAY

Exact temperature. Temperature range. Sky conditions. Feels-like. Dry period. Consecutive days. Or composite triggers that combine temperature, humidity and wind.

WHAT YOU GET

• Forecast-based predictions with confidence scoring, so you can see what's coming
• Background monitoring that checks conditions and notifies you when they line up
• Real hourly forecast data from Apple WeatherKit
• Temperature history with yesterday, last week and monthly trend charts
• Quiet hours and daily notification limits, so it never nags
• GPS or pick any city manually
• Siri and Shortcuts support for creating reminders by voice
• Spotlight search across your reminders
• Full data export and one-tap deletion of everything
• Native iOS 26 Liquid Glass design, in light and dark

HONEST ABOUT DATA

SunHat has no accounts and no sign-up. Your location is used to fetch a forecast and nothing else. There is no SunHat analytics SDK, no behavioral profile, no data sale. The free version shows banner ads through Google AdMob, and you can turn those off permanently with the optional SunHat Ad-Free subscription. Everything else in the app is free, forever, with no feature gates.

Full data export and deletion are built in, not buried.

SUNHAT AD-FREE

An optional auto-renewable subscription that removes all ads. $1.00/month or $10.00/year (two months free on the annual plan). Both plans unlock the same thing, and you can switch between them at any time.

Payment is charged to your Apple Account at confirmation of purchase. The subscription renews automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in your Apple Account settings.

Terms of Use: https://sunhat.apphq.online/terms
Privacy Policy: https://sunhat.apphq.online/privacy

Requires iOS 26 and a device with WeatherKit support. Weather data provided by Apple Weather.
---8<---
```

> The subscription paragraph is not optional boilerplate. Apple's
> Schedule 2 requires price, period, renewal terms, and cancellation
> instructions to appear in the binary **and** in the metadata.

### Keywords: 97/100

Comma-separated, no spaces after commas. Do not repeat words already in the
name or subtitle (`sunhat`, `weather`, `reminders`, `forecast`, `alerts`,
`plans`), Apple already indexes those, so repeating them wastes budget.

```
---8<---
rain,temperature,humidity,outdoor,gardening,running,hiking,todo,task,notify,sunny,tracker,climate
---8<---
```

### What's New: 1.0

```
---8<---
First release.

SunHat watches the forecast and reminds you when the weather matches your plans, not when the clock says so.

• Seven trigger types, from a simple temperature range to composite temperature + humidity + wind
• Background monitoring with quiet hours and daily notification limits
• Real WeatherKit hourly data and temperature history
• Siri, Shortcuts and Spotlight support
• Full data export and deletion
• English and Spanish
---8<---
```

---

## 3. Spanish (Mexico) localization

App Store Connect will not let a Spanish-localized app ship without these.

| Field | Value |
|---|---|
| **Name** | `SunHat: Clima y Recordatorios` (29/30) |
| **Subtitle** | `Avisos según el pronóstico` (26/30) |
| **Keywords** | `lluvia,temperatura,humedad,jardin,correr,senderismo,tarea,pendiente,soleado,clima,aire libre` |

```
---8<---
La mayoría de los recordatorios preguntan cuándo. SunHat pregunta con qué clima.

Un recordatorio de calendario para "salir a correr" suena igual haga sol o caiga aguanieve. Pero algunos planes no dependen del reloj: dependen del clima. Con SunHat describes las condiciones que estás esperando, y la app vigila el pronóstico y te avisa en cuanto la realidad coincide.

ALGUNOS EJEMPLOS

• "Salir a correr cuando esté entre 13 y 21 °C y despejado"
• "Regar el jardín cuando lleve 48 horas sin llover"
• "Día de playa cuando pase de 27 °C y no venga lluvia"

SIETE FORMAS DE DESCRIBIR UN DÍA

Temperatura exacta. Rango de temperatura. Estado del cielo. Sensación térmica. Periodo seco. Días consecutivos. O disparadores compuestos que combinan temperatura, humedad y viento.

LO QUE INCLUYE

• Predicciones con nivel de confianza basadas en el pronóstico
• Monitoreo en segundo plano que te avisa cuando se cumplen las condiciones
• Datos por hora reales de Apple WeatherKit
• Historial de temperatura con tendencias de ayer, la semana pasada y el mes
• Horas de silencio y límite diario de notificaciones
• GPS o selección manual de ciudad
• Compatible con Siri, Atajos y Spotlight
• Exportación y borrado total de tus datos
• Diseño nativo Liquid Glass de iOS 26, en claro y oscuro

TRANSPARENCIA CON TUS DATOS

SunHat no tiene cuentas ni registro. Tu ubicación se usa para obtener el pronóstico y nada más. No hay SDK de analítica propio, ni perfilado, ni venta de datos. La versión gratuita muestra anuncios de Google AdMob, y puedes quitarlos de forma permanente con la suscripción opcional SunHat Ad-Free. Todo lo demás es gratis, siempre, sin funciones bloqueadas.

SUNHAT AD-FREE

Suscripción opcional de renovación automática que elimina todos los anuncios. $1.00 al mes o $10.00 al año (dos meses gratis en el plan anual). Ambos planes desbloquean lo mismo y puedes cambiar entre ellos cuando quieras.

El pago se carga a tu cuenta de Apple al confirmar la compra. La suscripción se renueva automáticamente salvo que la canceles al menos 24 horas antes de que termine el periodo en curso. Puedes gestionarla o cancelarla en los ajustes de tu cuenta de Apple.

Términos de uso: https://sunhat.apphq.online/terms
Política de privacidad: https://sunhat.apphq.online/privacy

Requiere iOS 26 y un dispositivo compatible con WeatherKit. Datos meteorológicos proporcionados por Apple Weather.
---8<---
```

---

## 4. Screenshots

Required sizes for an iPhone-only app. App Store Connect accepts one set and
scales down, but supplying both avoids letterboxing complaints.

| Display | Resolution | Device to capture on | Required |
|---|---|---|---|
| 6.9" | 1320 × 2868 | iPhone 17 Pro Max | **Yes** |
| 6.5" | 1242 × 2688 | iPhone 11 Pro Max sim | Recommended |

Up to 10 per size. Suggested order, the first two are what most people
actually see, so they carry the whole pitch:

1. **Dashboard, a reminder ready now**: caption "Know the moment conditions match"
2. **Reminder creation, temperature range**: "Describe the day you're waiting for"
3. **Weather tab with predictions**: "See what's coming, with confidence"
4. **Reminders list**: "Seven ways to describe a day"
5. **Settings / quiet hours**: "It never nags"
6. **Paywall**: "Optional. Everything else is free"

### Capture procedure

`Screenshots/` and `Screenshots/Light/` hold README captures taken on an
iPhone 17 Pro (6.3"). **Those cannot be used for the App Store**, Connect's
required slot is 6.9", and no Pro Max simulator exists on this machine yet.

```bash
xcrun simctl create "iPhone 17 Pro Max" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max \
  com.apple.CoreSimulator.SimRuntime.iOS-26-5
```

Then capture, with the app in a known state (a reminder that reads as ready,
a couple in the list) so every shot shows real content rather than empty
states:

```bash
SIM=$(xcrun simctl list devices | grep "iPhone 17 Pro Max" | grep -oE '[0-9A-F-]{36}' | head -1)
xcrun simctl boot "$SIM"
xcrun simctl io "$SIM" screenshot ~/Desktop/sunhat-appstore/01-dashboard.png
```

Uninstall the app between light and dark passes, appearance is read at first
launch and a warm relaunch keeps the old one.

`VisualQAScreenshotTests` writes light, dark, AX-XXXL and Spanish captures to
`/tmp/sunhat-shots` on whichever simulator it runs on. Those are for design
review, not the store: they're 6.3" and they include the four-variant matrix
rather than a curated marketing sequence.

> **Do not** add device frames, drop shadows, or marketing chrome that
> misrepresents the UI. Apple rejects screenshots showing UI the app
> doesn't have. Captions rendered *above* the device shot are fine and
> standard; painted-on fake status bars and invented UI are not.

---

## 5. App Privacy (nutrition labels)

The app's own manifest is `SunHat/PrivacyInfo.xcprivacy`, which sets
`NSPrivacyTracking = true`. Declare in App Store Connect:

### Data Used to Track You

| Type | Collected by | Purpose |
|---|---|---|
| Device ID (advertising identifier) | Google Mobile Ads | Third-party advertising |
| Advertising Data | Google Mobile Ads | Third-party advertising |

### Data Not Linked to You

| Type | Collected by | Purpose |
|---|---|---|
| Precise Location | SunHat | App functionality (fetching a forecast) |
| Coarse Location | SunHat | App functionality |
| Advertising Data, Product Interaction, Crash Data, Performance Data | Google Mobile Ads | Analytics, advertising |

Cross-check Google's own publisher guidance at
<https://support.google.com/admob/answer/10787689> at submission time, the
list changes.

### Data Linked to You

None. SunHat has no accounts.

🔴 **Blocker:** `NSPrivacyTrackingDomains` in `SunHat/PrivacyInfo.xcprivacy`
is still **empty**. Apple expects a non-empty domain list whenever
`NSPrivacyTracking` is `true`. Populate from Google's current published list
at <https://developers.google.com/admob/ios/privacy>, read it at go-live
rather than reusing an old copy. Verified that GoogleMobileAds 12.14.0 and
UserMessagingPlatform 3.1.0 declare neither key in their own manifests, so
this file is the app's only tracking declaration.

---

## 6. Subscriptions

Product IDs are already final in code and in `SunHat.storekit`. Create them
**verbatim** or the app will not find them.

**Group:** `SunHat Ad-Free`, group display name (user-visible) `SunHat Ad-Free`

Both products at **the same group level (rank 1)** so switching plans is a
crossgrade, matching the local StoreKit config.

### `org.wesley.sunhat.adfree.monthly`

| Field | Value |
|---|---|
| Reference name | `Ad-Free Monthly` |
| Duration | 1 month |
| Price | $1.00 (US base tier) |
| Display name (en) | `Ad-Free Monthly` |
| Description (en) | `Removes all ads from SunHat.` |
| Display name (es) | `Sin anuncios, Mensual` |
| Description (es) | `Elimina todos los anuncios de SunHat.` |

### `org.wesley.sunhat.adfree.yearly`

| Field | Value |
|---|---|
| Reference name | `Ad-Free Annual` |
| Duration | 1 year |
| Price | $10.00 (US base tier) |
| Display name (en) | `Ad-Free Annual` |
| Description (en) | `Best value, two months free vs. monthly.` |
| Display name (es) | `Sin anuncios, Anual` |
| Description (es) | `La mejor oferta: dos meses gratis frente al plan mensual.` |

### Required before review

- [ ] Paid Applications agreement signed, banking and tax complete
- [ ] Group display name set
- [ ] Localized display name + description for **both** `en` and `es` on
      **both** products, a missing localization is an automatic flag
- [ ] Price set in every storefront (set the base tier; ASC generates the rest)
- [ ] **A review screenshot of the paywall attached to each product**: Apple
      requires one per subscription. Capture from `PaywallScreenshotTests`
      (`/tmp/sunhat-shots/paywall-sheet.png`)

---

## 7. App Review information

### Notes to reviewer

```
---8<---
SunHat is a weather-triggered reminder app. You describe weather conditions; the app watches the forecast and notifies you when they match.

No account or login is required. There is nothing to sign in to.

HOW TO SEE THE CORE FEATURE
1. Allow location and notifications when prompted (both are optional; the app works with a manually chosen city).
2. Tap the + button in the tab bar to create a reminder.
3. Choose a temperature range that matches current conditions where you are, so the trigger fires immediately.
4. The Dashboard shows it as ready, and a notification is sent.

MONETIZATION
The app is free and shows Google AdMob banner ads on the Dashboard and Weather tabs only. The optional auto-renewable subscription "SunHat Ad-Free" (monthly or annual, same entitlement, crossgradeable) removes them. There are no other paid features, nothing is gated behind the subscription.

Restore Purchases is at Settings > SunHat Ad-Free > Restore Purchases.

App Tracking Transparency is requested from the second session onward, for ad personalization only. Declining ATT does not reduce functionality; ads simply become non-personalized. In the EEA/UK, Google's UMP consent form is shown first, and no ad request is made until consent is resolved.

WEATHER DATA
Weather comes from Apple WeatherKit. The app never fabricates weather values, if a forecast is unavailable it says so rather than showing placeholder numbers.
---8<---
```

- **Demo account:** not required: leave blank, and tick "Sign-in required: No"
- **Contact:** Wesley Keetch, `weskcode@duck.com`
- **Attachment:** none needed

### Export compliance

`ITSAppUsesNonExemptEncryption` is already `false` in `SunHat/Info.plist`, so
App Store Connect will not ask. The app uses only HTTPS via system APIs.

### Content rights

The app contains no third-party content requiring rights documentation.
Weather data is Apple WeatherKit, which requires the attribution the app
already displays.

---

## 8. Attribution requirements

Apple's WeatherKit terms require attribution. Verify before submitting that
the app shows the Apple Weather mark and a link to the legal attribution page
on any screen displaying weather data.

---

## 9. Pre-submission checklist

### Owned by the developer (cannot be automated)

- [ ] Create AdMob app + 2 banner units; paste the 3 IDs (see
      `docs/MONETIZATION_GOLIVE.md` §1)
- [ ] Publish the AdMob GDPR consent message: without it, EEA/UK users get
      no ads at all (the app fails safe)
- [ ] Populate `NSPrivacyTrackingDomains`
- [ ] Create both subscription products with full `en` + `es` metadata and
      paywall review screenshots
- [ ] Bring `sunhat.apphq.online/privacy` and `/terms` in line with the in-app policy
      (advertising section, subscription terms)
- [ ] WeatherKit entitlement provisioning on the real App ID
- [ ] Verify `weskcode@duck.com` receives mail (App Review uses it)
- [ ] Capture 6.9" screenshots on an iPhone 17 Pro Max

### Verified in this repo

- [x] Deployment target iOS 26.0
- [x] `ITSAppUsesNonExemptEncryption = false`
- [x] All location usage descriptions present and specific
- [x] `NSUserTrackingUsageDescription` present
- [x] Background modes + `BGTaskSchedulerPermittedIdentifiers` declared
- [x] Release build succeeds with zero warnings
- [x] Full data export and deletion, covered by schema-parity tests
- [x] English + Spanish string catalogs complete
