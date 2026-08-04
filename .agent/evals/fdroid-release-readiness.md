# Task Eval: F-Droid Release Readiness

## Goal
- Prepare repository-owned release documentation, metadata, and GitHub-to-GitLab mirroring without changing GitHub's role as the source of truth.

## Acceptance Criteria
- [ ] Root MIT license and project README are present.
- [ ] GitHub Actions mirrors GitHub branches and tags to GitLab using scoped secrets.
- [ ] English Fastlane metadata exists and respects F-Droid length and path rules.
- [ ] A package-named F-Droid metadata draft uses facts extracted from the repository and marks unknowns as TODOs.
- [ ] Android release builds are not signed with the debug key.
- [ ] Documentation covers both GitLab pull mirroring and the default GitHub Actions workflow.
- [ ] Existing unrelated worktree changes are preserved.

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
- [ ] Configure GitHub Actions secrets and compare GitHub/GitLab commit IDs after the first run.
- [ ] Publish a new version and immutable tag after these readiness changes.
- [ ] Replace the disabled F-Droid build draft with the new version, version code, and full commit hash.
- [ ] Capture representative Android screenshots.

## Result
- Status: PARTIAL
- Evidence:
  - `flutter analyze`: PASS, no issues found.
  - `flutter test`: PASS, 233 tests passed.
  - `flutter build apk --release`: PASS, produced
    `app/build/app/outputs/flutter-apk/app-release.apk`.
  - `apksigner verify`: expected failure with no signing manifest, confirming
    the release APK is unsigned rather than debug-signed.
  - `aapt dump badging`: application ID `com.zengtao.travelspendplus`,
    version name `1.0.0`, version code `12`.
  - Local bare-repository simulation: branch/tag mirror refspecs synchronized
    `main` and all existing tags to the same commit IDs.
  - Remote verification: GitHub and GitLab `main` and tag refs currently match.
  - YAML parsing, metadata length checks, and `git diff --check`: PASS.
- Remaining risks:
  - GitHub Actions credentials have not been configured or verified.
  - The current release tag predates these release-readiness changes.
  - F-Droid's scanner must still independently review native assets supplied by `sqlite3` 3.x.
  - `fdroid` and `actionlint` are not installed locally, so their native lint
    checks have not been run.
