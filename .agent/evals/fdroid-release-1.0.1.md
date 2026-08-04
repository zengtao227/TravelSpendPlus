# Task Eval: F-Droid Release 1.0.1+13

## Goal

- Publish `1.0.1+13` from the canonical GitHub repository, mirror its source
  and tag to GitLab, and prepare a reviewable first F-Droid submission.

## Acceptance Criteria

- [ ] `app/pubspec.yaml` declares `version: 1.0.1+13` and changelog `13.txt`
  describes the release.
- [ ] The Android application ID remains `com.zengtao.travelspendplus`.
- [ ] No release build uses the Android debug signing key.
- [ ] The direct `sqlite3_flutter_libs` dependency is removed or its continued
  use is justified with F-Droid-compatible evidence.
- [ ] Two to four representative, redistributable Android screenshots exist in
  fastlane metadata.
- [ ] Flutter analysis, tests, and the release build pass.
- [ ] Intentional release files are committed and pushed to GitHub `main`
  without overwriting unrelated user changes.
- [ ] GitLab `main` and tag `v1.0.1+13` resolve to the same commits as GitHub.
- [ ] A GitHub Release exists for `v1.0.1+13`; any attached upstream APK is
  release-signed, never debug-signed or unsigned.
- [ ] F-Droid metadata names the immutable release commit and passes available
  metadata/build checks.
- [ ] A submission is opened against F-Droid `fdroiddata`, or the exact external
  authorization/credential/reviewer blocker is recorded.

## Verification

- Command: `flutter analyze` (from `app/`)
- Expected: no issues.
- Command: `flutter test` (from `app/`)
- Expected: all tests pass.
- Command: `flutter build apk --release` (from `app/`)
- Expected: unsigned APK builds successfully for F-Droid.
- Command: `aapt dump badging build/app/outputs/flutter-apk/app-release.apk`
- Expected: package `com.zengtao.travelspendplus`, version name `1.0.1`, code
  `13`.
- Command: `apksigner verify build/app/outputs/flutter-apk/app-release.apk`
- Expected: failure before F-Droid signing; an upstream Release APK, if any,
  must be verified separately and succeed.
- Command: `ruby -e 'require "yaml"; YAML.load_file(ARGV[0])' docs/fdroid/com.zengtao.travelspendplus.yml`
- Expected: exits zero.
- Command: compare `git ls-remote` for GitHub and GitLab main/tag refs.
- Expected: identical object IDs.

## Manual Checks

- [ ] Screenshots show real app UI without personal or fabricated sensitive
  data and render correctly.
- [ ] GitHub Actions mirror secrets are configured without exposing their
  values.
- [ ] GitHub Release notes and F-Droid descriptions are accurate and avoid
  unsupported privacy claims.
- [ ] F-Droid submission status and reviewer findings are recorded accurately.

## Result

- Status: PARTIAL
- Evidence:
  - Baseline `1.0.0+12` analysis, 233 tests, and unsigned release build passed
    before the version bump.
  - GitHub and GitLab baseline main/tag refs matched on 2026-08-03.
- Remaining risks:
  - GitHub/GitLab/F-Droid credentials and repository permissions have not yet
    been confirmed.
  - The SQLite native dependency and screenshot automation still require
    inspection.
