# SunHat Open-Source Readiness Audit

Generated 2026-08-27. Scope: full repository inspection (git history, tracked files, GitHub repo metadata, CI, docs) ahead of a possible private-to-public visibility change for `weskcode/sunhat`.

**Headline finding: the repository is already substantially prepared for public release.** Prior commits (`Concurrency hardening, privacy completeness, and repo professionalization`, `Polish all repo-facing files for professionalism and clarity`, `Hide internal files from public repo`, `docs: add repository description, topics, and genuine screenshot gallery`, `fix: clarify SunHat is a private project, not open source`, `chore: remove screenshot-generation infra and polish README/description`) already did most of the work this audit would normally recommend: MIT license, a real README, `SECURITY.md`, `CONTRIBUTING.md`, issue/PR templates, curated public screenshots, and untracking of internal-only docs. This audit verifies that work and identifies what's left.

---

## 1. What the project is

SunHat is a weather-triggered reminder app for iOS (SwiftUI, SwiftData, WeatherKit primary / OpenWeatherMap backup, iOS 26+, Swift 6.2). MVVM architecture, zero third-party dependencies (Apple frameworks only — confirmed, no `Package.swift`, `Podfile`, or `Cartfile` anywhere in the repo). Full description and architecture are already accurately documented in `README.md`; this audit does not restate them.

## 2. Repository metadata (current)

| Field | Value |
|---|---|
| Repo | `weskcode/sunhat` |
| Visibility | **PRIVATE** |
| Default branch | `main` |
| License (GitHub-detected) | MIT |
| Topics | ios, ios-app, mvvm, reminders, swift, swiftdata, swiftui, weather, weatherkit |
| Issues | enabled |
| Security policy | enabled (`SECURITY.md` recognized) |
| Homepage URL | not set (candidate: `sunhat.app`, referenced in internal docs) |

## 3. Build and test verification (actually executed, not assumed)

To get a true read on what a fresh public clone would experience, the pre-existing **unrelated uncommitted work** in the working tree (a large in-progress UI/UX simplification pass, ~32 files, unconnected to open-source prep) was temporarily set aside with `git stash` (scoped to exactly those files) and restored afterward. Nothing was lost; see §9.

Against the actual committed `main` HEAD:

- `xcodebuild -scheme SunHat -configuration Debug -destination 'generic/platform=iOS Simulator' build` → **BUILD SUCCEEDED, zero errors, zero warnings.** Confirms the README's "zero warnings" claim.
- `xcodebuild -scheme SunHat -destination 'platform=iOS Simulator,id=20465D2E-7941-46FD-BAE2-21335FE5F0B1' -only-testing:SunHatTests test` → **260 tests / 52 suites passed, zero failures.**

One local-only obstruction was found and removed during verification: `SunHat/Views/Components/ReminderIconColorPicker 2.swift`, an **untracked** stale duplicate (a macOS iCloud/Documents-folder sync conflict copy — this project directory lives under `~/Documents`, which is iCloud-synced) containing an older, pre-audit-fix version of the file. It was never part of git (confirmed via `git ls-files`), so it never affected any clone but this machine's; TODO.md documents three earlier instances of the same phenomenon being cleaned up on July 21. Deleted; had no effect on the tracked tree.

## 4. Security scan results

No `gitleaks`/`trufflehog` binary was available locally (checked via `which`; not installed via Homebrew). Performed manual pattern-based scanning instead: regex sweep of the current tracked tree, and `git log --all -G<pattern>` (pickaxe) sweeps across full history for API-key/token/secret/private-key/AWS-key/GitHub-token/password patterns, plus a filename sweep across all commits for `*.p8`, `*.p12`, `*.pem`, `*.key`, `*.mobileprovision`, `*.cer`, `.env`.

**Result: no hardcoded secrets, credentials, private keys, or provisioning profiles found in the current tree or anywhere in git history.**

- The only "API key"-shaped code is `WeatherServiceConfiguration.swift`'s `WeatherCredentialStore`, which reads the OpenWeatherMap key from the **iOS Keychain** (`kSecClassGenericPassword`) or an environment variable (`OPENWEATHERMAP_API_KEY`) at runtime — never a literal string. Test files use obvious placeholder strings (`"test-api-key"`).
- The only sensitive-looking filenames ever committed are `SunHat/Resources/Configuration/APIKeys.plist.example` (and a `hatti/`-prefixed twin, see §8) — both `.example` templates with no real values.
- `sk-` and `p8` pickaxe hits were false positives (`task-based` substring; `.gitignore` entries adding `*.p8`), verified by direct inspection.
- Apple Developer Team ID `HD39MR492X` appears 8 times in `SunHat.xcodeproj/project.pbxproj` (all `DEVELOPMENT_TEAM` build settings). **Not a secret** — it cannot be used to sign or access anything without the associated private key/certificate, which is not in the repo — but it does tie the public repo to a specific real-world Apple Developer account. Purely a judgment call; flagged in §10 rather than changed unilaterally.

### Historical exposure (files removed from tracking, still recoverable via `git log`)

Commit `3fe659b` ("Hide internal files from public repo") removed several categories of file from git tracking and added them to `.gitignore`, but **removing a file from the current tree does not remove it from history** — anyone who clones the repo can still run `git show <old-commit>:<path>` or `git log -p` to recover:

- Internal docs: `CLAUDE.md`, `CODE_AUDIT.md` (this audit's own predecessor — candid UX critique, e.g. describing the app's prior look as "vibe-coded"), `TODO.md`, `WIDGET_SETUP.md`, `WATCHOS_PORT_PLAN.md`, `IPAD_PORT_PLAN.md`
- App Store screenshot sets and a screenshot-generation script (`AppStore/Screenshots*/`)
- `buildServer.json` — contained a **stale local path** revealing the developer's username and an unrelated former project name (`/Users/wesleykeetch/Documents/Developer/hatti/...`); not a credential, but personal/machine-identifying information
- `buildnumber.txt`, `.claude/settings.local.json`, `.vercel/project.json`, `.vscode/settings.json`

**None of this is a credential leak** — no keys, tokens, or passwords were found in any of it. It is internal engineering process content the repo owner clearly intended to keep private (per the `.gitignore` comment "Internal docs (not needed in public repo)"), and it stays technically recoverable from history unless history is rewritten. This is a genuine decision point, not something this audit resolves unilaterally — see §10.

## 5. Dependency and supply-chain review

No dependency manifests exist (`Package.swift`, `Package.resolved`, `Podfile`, `Cartfile` — none found anywhere in the repo). Nothing to vulnerability-scan; the README's "no third-party dependencies" claim is accurate.

## 6. CI / GitHub Actions review

`.github/workflows/ios-build.yml` (single workflow, "iOS Build"):
- Triggers: `pull_request`, `push` to `main`. Runs `xcodebuild build-for-testing` on `macos-latest` with a 30-minute timeout.
- Uses `actions/checkout@v4` (official action, mutable major-version tag — common practice; pinning to a full commit SHA is stricter but not necessary given this workflow uses no secrets and performs no privileged operations).
- **No `permissions:` block**, so the job inherits the repository's default `GITHUB_TOKEN` permissions rather than declaring least-privilege explicitly. Since the workflow only checks out and builds, it needs `contents: read` and nothing else. Recommended low-risk fix (applied on the release-prep branch, not yet pushed): add an explicit `permissions: contents: read` block.
- No secrets are referenced anywhere in the workflow. No deploy/publish/release steps exist that could unexpectedly ship anything on a public push or on a fork's PR.
- Would work for external contributors as-is (nothing requires a private secret to run).

## 7. Documentation quality review

`README.md`, `CONTRIBUTING.md`, and `SECURITY.md` were all read in full. None of them read as generic or AI-generated filler — they are specific to this codebase (real file paths, real architectural rules, real "non-negotiables" tied to actual code behavior like the anti-fabrication rule and the privacy-deletion schema-parity test), concise, and don't make unverifiable marketing claims. No changes recommended to their content. Issue and PR templates are similarly short, specific, and useful (the PR template's checklist matches CONTRIBUTING.md's actual requirements).

## 8. Naming-history curiosity (non-blocking)

Git history contains one path fragment under a `hatti/` prefix (`hatti/Resources/Configuration/APIKeys.plist.example`, another `.example` template, no real values) and `buildServer.json`'s stale reference to a `hatti` project. This suggests the repo was renamed/repurposed from an earlier project called "hatti" at some point in its history. Not a security issue (no secrets involved) and not investigated further — noted for completeness only.

## 9. Preserved unrelated work

The working tree has a large **unrelated, uncommitted** in-progress change (~32 files: UI/UX simplification of onboarding, location, and settings screens, matching recommendations in `CODE_AUDIT.md`). This was **not touched** beyond one mechanical fix made before this task began (restoring an accidentally-deleted `weatherSlide` transition helper that was breaking the Debug build — see `SunHat/Utilities/Motion/SunHatMotion.swift`). None of this will be included in the open-source-prep commit; only files this task specifically changes will be staged.

## 10. Open decisions for the repository owner

These are not resolved by this audit and require an explicit choice:

1. **Git history exposure of internal docs/screenshots/build config** (§4). Options: (a) accept it — no credentials are exposed, only internal process notes and a stale local path, and rewriting history on a repo with an existing remote and (per `git log`) presumably no other clones is disruptive but not unsafe; (b) rewrite history to purge these paths entirely (e.g. `git filter-repo`). **This audit will not rewrite history without explicit authorization**, per the governing instructions.
2. **`DEVELOPMENT_TEAM` Apple Team ID in `project.pbxproj`** (§4). Low severity, optional redaction — leaving it in is common practice and doesn't grant access to anything, but it does deanonymize the repo to a specific Apple Developer account.
3. **Homepage URL** — GitHub repo metadata has none set; `sunhat.app` is referenced elsewhere in (currently untracked) internal docs as the live marketing/privacy-policy site. Could be set via `gh repo edit --homepage`.

## 11. Proposed cleanup plan

Given the findings above, there is very little left to clean up — most of Phase 3's normal targets (stray docs, build artifacts, IDE config, unused assets, dead scripts) were already handled in prior commits. Classification of everything relevant:

| Item | Classification | Action |
|---|---|---|
| `.github/workflows/ios-build.yml` permissions | Update | Add explicit `permissions: contents: read` |
| `README.md`, `CONTRIBUTING.md`, `SECURITY.md`, `LICENSE`, issue/PR templates | Keep | Already accurate and well-written; verified against actual repo state |
| Historical internal docs / screenshots in git history | Needs owner confirmation | See §10.1 |
| `DEVELOPMENT_TEAM` in `project.pbxproj` | Needs owner confirmation | See §10.2 |
| Homepage URL | Needs owner confirmation | See §10.3 |
| Stray untracked `ReminderIconColorPicker 2.swift` | Removed | Local-only iCloud sync artifact, never tracked; deleted during verification (§3) |
| Unrelated uncommitted UI refactor (~32 files) | Keep, out of scope | Preserved untouched, excluded from this task's commit (§9) |
| Empty directories `SunHat/Utilities/Extensions`, `SunHat/Services/Network` | Keep | Pre-existing (mtime Jan 30 2026), untrackable by git (no content), harmless |

No files are proposed for deletion from the current tracked tree — the tracked tree is already clean.
