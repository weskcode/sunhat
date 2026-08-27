# SunHat Open-Source Release Report

Generated 2026-08-27. Final report for the `chore/open-source-release-prep` branch, following the findings in [open-source-readiness-audit.md](open-source-readiness-audit.md).

## Summary of changes

Two files changed, both additive/non-functional to the app itself:

- **Added** `docs/open-source-readiness-audit.md` — full discovery, security scan, and cleanup-plan writeup.
- **Updated** `.github/workflows/ios-build.yml` — added an explicit `permissions: contents: read` block (least-privilege hardening; the workflow previously relied on the repository's default token permissions).

No files were removed. The tracked tree was already clean going into this task — prior commits (`3fe659b` and others, see the audit doc §4) had already untracked internal docs, App Store assets, and IDE config, and already established a real README, MIT license, `SECURITY.md`, `CONTRIBUTING.md`, and issue/PR templates.

One local-only untracked file (`SunHat/Views/Components/ReminderIconColorPicker 2.swift`, a stale iCloud sync conflict copy) was deleted during build verification. It was never part of git and never affected any other clone.

Repository metadata: homepage URL set to `https://sunhat.app` via `gh repo edit --homepage` (per owner confirmation).

## Files removed and why

None.

## Files added and why

- `docs/open-source-readiness-audit.md` — Phase 1/2/3 discovery, security audit, and cleanup plan, per the governing task instructions.
- `docs/open-source-release-report.md` (this file) — final report, per the governing task instructions.

## Files updated

- `.github/workflows/ios-build.yml` — added `permissions: contents: read`.

## Security scan results

No hardcoded secrets, API keys, credentials, private keys, certificates, or provisioning profiles found in the current tracked tree or anywhere in git history (manual pattern scan + `git log --all -G<pattern>` pickaxe search across the full history, since `gitleaks`/`trufflehog` were not available locally — see audit doc §4 for the exact method). The app's only third-party credential (OpenWeatherMap API key) is read from the iOS Keychain or an environment variable at runtime, never hardcoded.

**Historical secret findings:** none. The only historical exposure is non-credential internal content (see below), which the repository owner has reviewed and explicitly chosen to accept rather than remediate via history rewrite.

## Historical exposure (accepted, not remediated — owner decision)

Presented to the repository owner directly; decision: **accept as-is**, do not rewrite history. Internal docs (`CLAUDE.md`, `CODE_AUDIT.md`, `TODO.md`, port-plan docs), old App Store screenshots, and `buildServer.json` (which reveals a local username/path and a stale unrelated project name) remain recoverable via `git show <old-commit>:<path>` from commits prior to `3fe659b`. No credentials are present in any of it. Documented for the record; no further action planned.

**Apple Developer Team ID** (`HD39MR492X`, 8 occurrences in `project.pbxproj`): reviewed and explicitly left in place per owner decision — not a secret, cannot be used to sign or access anything without the associated private key.

## Dependency findings

No dependency manifests exist in the repository (`Package.swift`, `Package.resolved`, `Podfile`, `Cartfile` — none found). Zero third-party dependencies; nothing to scan for vulnerabilities.

## Build and test results (against the actual committed state)

- `xcodebuild -scheme SunHat -configuration Debug -destination 'generic/platform=iOS Simulator' build` → **BUILD SUCCEEDED**, zero errors, zero warnings. Run twice: once against the pre-existing committed `main` HEAD (with the unrelated WIP set aside), once again against the final `chore/open-source-release-prep` commit. Both succeeded identically.
- `xcodebuild -scheme SunHat -destination 'platform=iOS Simulator,id=20465D2E-7941-46FD-BAE2-21335FE5F0B1' -only-testing:SunHatTests test` → **260 tests / 52 suites passed**, zero failures, run against the committed `main` HEAD.
- `.github/workflows/ios-build.yml` validated as syntactically correct YAML (Python `yaml.safe_load` and Ruby `YAML.load_file`, both succeeded).

## CI changes

Added explicit least-privilege `permissions: contents: read` to the only workflow (`ios-build.yml`). No other CI changes; the workflow already required no secrets, performed no deploy/publish steps, and would already work for an external contributor's fork.

## License status

MIT License already present (`LICENSE`, copyright Wesley Keetch, 2026), correctly referenced from `README.md`, and correctly detected by GitHub (`licenseInfo.key: "mit"`). No action needed.

## Remaining concerns

- Historical git content (internal docs, old screenshots, a stale local path in `buildServer.json`) remains technically recoverable from pre-`3fe659b` commits. Accepted by the owner; no credentials involved.
- `DEVELOPMENT_TEAM` Apple Team ID remains in `project.pbxproj`. Accepted by the owner.
- No `CODE_OF_CONDUCT.md` exists. Not added — `CONTRIBUTING.md` already sets clear scope/contribution expectations for what is a small, single-maintainer project, and adding process files "to look busy" was explicitly out of scope per the governing instructions. Worth reconsidering only if the project later takes on outside maintainers.
- `actions/checkout@v4` is pinned to a mutable major-version tag rather than a full commit SHA. Common practice; not changed, since the workflow handles no secrets and has no privileged operations, but noted for anyone who wants maximum supply-chain hardening later.

## Required manual actions

None outstanding. Homepage URL was set in this session with owner approval.

## Public-release recommendation

**Ready to publish**, pending the explicit visibility-change confirmation below.

## Git state

- Branch: `chore/open-source-release-prep`
- Commit: `364de58ab0e5ad4a4665a7ba40e7622a8cbc6269`
- `main` unchanged at `8f9eebd4ba444c2540aeafa2b0480a831300c3fc`
- Working tree still carries the pre-existing, unrelated, uncommitted UI/UX refactor (~32 files) — preserved untouched throughout, not included in this branch's commit.
- Nothing pushed. No force-push, no history rewrite, no branch deletion performed.
