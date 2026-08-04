# Task Eval: F-Droid Release 1.0.1+13

## Goal

- Publish `1.0.1+13` from the canonical GitHub repository, mirror its source
  and tag to GitLab, and prepare a reviewable first F-Droid submission.

## Acceptance Criteria

- [x] `app/pubspec.yaml` declares `version: 1.0.1+13` and changelog `13.txt`
  describes the release.
- [x] The Android application ID remains `com.zengtao.travelspendplus`.
- [x] No release build uses the Android debug signing key.
- [x] The direct `sqlite3_flutter_libs` dependency is removed or its continued
  use is justified with F-Droid-compatible evidence.
- [x] Two to four representative, redistributable Android screenshots exist in
  fastlane metadata.
- [x] Flutter analysis, tests, and the release build pass.
- [x] Intentional release files are committed and pushed to GitHub `main`
  without overwriting unrelated user changes.
- [x] GitLab `main` and tag `v1.0.1+13` resolve to the same commits as GitHub.
- [x] A GitHub Release exists for `v1.0.1+13`; any attached upstream APK is
  release-signed, never debug-signed or unsigned.
- [x] F-Droid metadata names the immutable release commit and passes available
  metadata/build checks.
- [x] A submission is opened against F-Droid `fdroiddata`, or the exact external
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

- [x] Screenshots show real app UI without personal or fabricated sensitive
  data and render correctly.
- [x] GitHub Actions mirror secrets are configured without exposing their
  values.
- [x] GitHub Release notes and F-Droid descriptions are accurate and avoid
  unsupported privacy claims.
- [x] F-Droid submission status and reviewer findings are recorded accurately.

## Result

- Status: PARTIAL — repository release work is complete; F-Droid review is external.
- Evidence:
  - `flutter analyze`: PASS with no issues.
  - `flutter test`: PASS, 234 tests.
  - `flutter build apk --release`: PASS, 65.9 MB unsigned APK.
  - APK package/version: `com.zengtao.travelspendplus`, `1.0.1`, code `13`.
  - Upstream APK signature: v2/v3 PASS; SHA-256
    `4f681a930728bb1156660f1b2bd9e2195ed4216a934fde3a5d1c619dd669758e`.
  - GitHub Actions mirror runs for `main` and `v1.0.1+13`: PASS.
  - GitHub and GitLab release tag both resolve to
    `6c9d3c551838cf08b85cab70df56f24ac3c35460`.
  - GitHub Release published with verified signed APK.
  - F-Droid submission opened as `fdroid/fdroiddata!44806`.
  - Official `fdroidserver 2.4.2` parser, `fdroid lint`, and update-check
    simulation: PASS; the update rule found `1.0.1 (13)` at the release commit.
- Remaining risks:
  - GitLab refused to start fork/MR CI jobs until account identity verification;
    the MR asks F-Droid maintainers to trigger authoritative upstream CI.
  - F-Droid reviewers must independently accept the dependency scan and build.
  - The upstream private signing key requires a separate secure backup.
