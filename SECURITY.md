# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in SunHat, please report it responsibly.

**Do not open a public GitHub issue for security vulnerabilities.**

Instead, email: **security@sunhat.app**

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

We will respond within 48 hours and work with you to understand and address the issue.

## Scope

SunHat is a privacy-focused iOS app. The following are in scope:

- Data leakage (location, reminder data, user preferences)
- Unauthorized data access or exfiltration
- Authentication/authorization bypass
- Injection attacks via notification deep-links or App Intents
- Weather data manipulation or spoofing

## Out of Scope

- Physical attacks on devices
- Social engineering
- Issues in third-party services (Apple WeatherKit, iCloud)

## Privacy

SunHat stores all data locally on-device. No personal data is transmitted to any server except weather queries to Apple WeatherKit (using your coordinates to fetch a forecast). There are no accounts, no analytics, and no third-party SDKs.

If you find a way to exfiltrate data from the app, that is a critical vulnerability — please report it immediately.
