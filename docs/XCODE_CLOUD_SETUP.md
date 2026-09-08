# Xcode Cloud setup

SunHat moved off GitHub Actions for build/test/archive automation on
September 8, 2026. GitHub bills macOS runners at a 10x minute multiplier on
every plan, and the Free tier's 2,000 minutes/month for private repos
disappears fast running iOS builds. GitHub Actions also never produced a
submittable archive, only `build-for-testing`, so it wasn't replacing the
manual archive step anyway.

Xcode Cloud is Apple's own CI, billed in Apple compute hours (25/month free
on most paid Apple Developer Program memberships, separate from GitHub's
quota entirely), and it can go all the way to a TestFlight upload.

**Workflow creation itself has to happen in Xcode.** There's no file to
commit and no public CLI for it, unlike GitHub Actions' YAML. Everything
below the repo needs is already in place; what's left is a one-time setup
in the Xcode GUI.

## What's already prepared in this repo

- Both `SunHat` and `SunHatUnitTests` schemes are shared
  (`xcshareddata/xcschemes/`), which Xcode Cloud requires to see them.
- The Release build phase (`Set Build Number`) checks for `CI_BUILD_NUMBER`
  first and uses it as `CFBundleVersion` when set. Xcode Cloud sets that
  variable automatically, so no extra configuration is needed for build
  numbering once a workflow exists.
- `.gitignore` excludes `buildnumber.txt` (the local-only fallback) and
  `ci_scripts/` isn't needed for this project: dependencies are a single
  SPM package (Google Mobile Ads) that Xcode Cloud resolves on its own, no
  custom post-clone script required.

## One-time setup, in Xcode

1. Open `SunHat.xcodeproj` in Xcode.
2. **Product menu → Xcode Cloud → Create Workflow.**
3. Xcode Cloud asks to connect the GitHub repo (`weskcode/sunhat`) via the
   Apple Developer account. Grant access when prompted; this creates a
   GitHub App installation scoped to this repo, not a personal access
   token.
4. **Pin a stable Xcode version, not a beta.** In the workflow's
   Environment tab, set **Xcode Version** to a specific release build
   (e.g. `26.6`), never "Latest Release" or a beta. A CI environment that
   silently moves to a new Xcode version can start failing builds with no
   code change to point at, and beta Xcode archives are rejected at App
   Store submission regardless.
5. Configure two workflows:

   **Build and Test** (on every push and pull request to `main`)
   - Scheme: `SunHatUnitTests`
   - Action: Build, then Test
   - Destination: iPhone 17 Pro (or whatever current-generation simulator
     Xcode Cloud offers at the pinned Xcode version)

   **Archive and Distribute** (manual, or on a version tag)
   - Scheme: `SunHat`
   - Action: Archive
   - Post-Action: **TestFlight (Internal Testing)**, so a successful
     archive uploads automatically
   - Trigger: manual start, or push to a `release/*` branch, whichever
     matches how often you want a build to reach testers

6. Save. Xcode Cloud runs the first build automatically; watch it once in
   Xcode's Cloud tab or on App Store Connect to confirm both workflows
   pass before relying on them.

## What to verify once it's running

- [ ] The Build and Test workflow triggers on a PR and reports its status
      as a GitHub check (Xcode Cloud posts this automatically once the
      GitHub App is connected)
- [ ] The pinned Xcode version is a release build, confirmed in the
      workflow's Environment tab, not "Latest Release"
- [ ] An Archive and Distribute run produces a build visible in App Store
      Connect → TestFlight
- [ ] `CFBundleVersion` on that build matches Xcode Cloud's own build
      number, not a local `buildnumber.txt` value

## If a workflow needs to change

Workflow configuration lives in App Store Connect, not in this repo. To
edit triggers, the pinned Xcode version, or the test destination: Xcode's
Cloud tab, or appstoreconnect.apple.com → your app → Xcode Cloud →
Workflows. There's nothing to `git pull` for a workflow change.
