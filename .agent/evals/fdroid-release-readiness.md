# Task Eval: F-Droid Release Readiness

## Goal
- Prepare repository-owned release documentation, metadata, and GitHub-to-GitLab mirroring without changing GitHub's role as the source of truth.

## Acceptance Criteria
- [x] Root MIT license and project README are present.
- [x] GitHub Actions mirrors GitHub branches and tags to GitLab using scoped secrets.
- [x] English Fastlane metadata exists and respects F-Droid length and path rules.
- [x] Package-named F-Droid metadata uses the immutable release commit.
- [x] Android release builds are not signed with the debug key.
- [x] Documentation covers both GitLab pull mirroring and the default GitHub Actions workflow.
- [x] Existing unrelated worktree changes are preserved.

## Verification
- Command: `flutter analyze && flutter test`
- Expected: Analyzer and tests pass.
- Command: `flutter build apk --release`
- Expected: An unsigned Android release APK is produced without debug signing.
- Command: `ruby -e 'require "yaml"; YAML.load_file("docs/fdroid/com.zengtao.travelspendplus.yml"); YAML.load_file(".github/workflows/mirror-to-gitlab.yml")'`
- Expected: Both YAML files parse.
- Command: `git diff --check`
- Expected: No whitespace errors.

## Manual Checks
- [x] Add the public GitLab mirror URL to all TODO locations.
- [x] Configure GitHub Actions secrets and compare GitHub/GitLab commit IDs after the first run.
- [x] Publish a new version and immutable tag after these readiness changes.
- [x] Replace the disabled F-Droid build draft with the new version, version code, and full commit hash.
- [x] Capture representative Android screenshots.

## Result
- Status: PASS
- Evidence:
  - `flutter analyze`: PASS, no issues found.
  - `flutter test`: PASS, 234 tests passed.
  - `flutter build apk --release`: PASS, produced
    `app/build/app/outputs/flutter-apk/app-release.apk`.
  - `apksigner verify`: expected failure with no signing manifest, confirming
    the release APK is unsigned rather than debug-signed.
  - `aapt dump badging`: application ID `com.zengtao.travelspendplus`,
    version name `1.0.1`, version code `13`.
  - Local bare-repository simulation: branch/tag mirror refspecs synchronized
    `main` and all existing tags to the same commit IDs.
  - Remote verification: GitHub and GitLab `main` and tag refs currently match.
  - YAML parsing, metadata length checks, and `git diff --check`: PASS.
- Remaining risks:
  - F-Droid's scanner must independently review native assets supplied by
    `sqlite3` 3.x and approve merge request `fdroid/fdroiddata!44806`.
