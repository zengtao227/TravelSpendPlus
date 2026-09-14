# F-Droid Release Checklist

GitHub is the canonical repository. GitLab is an operational mirror for the
F-Droid workflow and must not receive independent development commits.

## Release Audit Summary

- Application ID: `com.zengtao.travelspendplus`
- License: MIT
- Flutter project directory: `app/`
- Source release version: `1.0.2+17`
- Published Android version codes: `171`, `172`, `173`
- Release tag: `v1.0.2`
- Pinned Flutter revision: `84fc5cbb223bc12f83d65b647ff8a56caf779ffd`
- GitHub source: `https://github.com/zengtao227/TravelSpendPlus`
- GitLab mirror: `https://gitlab.com/zengtao227/TravelSpendPlus`

Legacy `v1.0.1+<code>` tags remain immutable. From `1.0.2` onward releases use
`v<versionName>` tags plus ABI-specific Android version codes so F-Droid can
verify three reproducible split APKs against one GitHub Release.

## Before Publishing a Release

- [x] Confirm `app/pubspec.yaml` contains the intended `versionName+versionCode`.
- [x] Confirm the Android `applicationId` is
  `com.zengtao.travelspendplus`.
- [x] Confirm release builds do not use the debug signing configuration.
- [x] Run `flutter pub get`, `flutter analyze`, and `flutter test` from `app/`.
- [ ] Run `flutter build apk --release --split-per-abi` and locate all three
  unsigned ABI release APKs.
- [x] Review direct and transitive dependencies for non-free libraries,
  downloaded executables, and prebuilt native binaries.
- [x] Confirm `sqlite3_flutter_libs` remains absent. The project uses
  `sqlite3` 3.x, which bundles native assets without the obsolete Flutter
  plugin.
- [x] Add representative Android screenshots under
  `fastlane/metadata/android/en-US/images/phoneScreenshots/`.
- [x] Add changelogs for all three published Android version codes
  (`base*10+1`, `base*10+2`, `base*10+3`).
- [ ] Commit all release-readiness changes before creating the release tag.
- [ ] Create an immutable `v<versionName>` tag only after the split build passes.

## Upstream APK Signing

The F-Droid recipe uses reproducible builds, so this identity must sign all
three ABI APKs attached to each GitHub Release. F-Droid rebuilds them from
source and publishes the developer-signed APKs only after they match. The
private key and password must remain outside Git.

- Key alias: `travelspendplus`
- Certificate subject: `CN=TravelSpendPlus, O=zengtao227`
- Certificate SHA-256: `B4:58:E2:3E:5A:27:33:5F:9F:72:E8:DA:EE:04:EE:B2:AD:8C:DB:12:80:32:58:02:95:0B:E1:70:A2:A3:36:03`

## GitHub to GitLab Mirror Check

### Option 1: GitLab Premium Pull Mirror

GitLab pull mirroring is available on Premium and Ultimate tiers. In the
GitLab project, open **Settings > Repository > Mirroring repositories**, add
`https://github.com/zengtao227/TravelSpendPlus.git`, choose **Pull**, and save
the mirror. The public GitHub repository normally needs no token. If it later
becomes private, use a GitHub fine-grained token with read-only access to this
repository, or a classic token with the required repository read access.

Enable overwrite of diverged branches only when GitHub is confirmed as the
source of truth. Do not enable bidirectional mirroring.

This option is appropriate when the GitLab subscription already includes pull
mirroring and scheduled synchronization is preferred over a GitHub workflow.

### Option 2: GitHub Actions Push to GitLab (Default)

1. Create an empty, public GitLab project. Do not initialize it with a README,
   license, or `.gitignore`.
2. On GitLab.com Free, create a personal access token with only the
   `write_repository` scope and access to the mirror project. Project access
   tokens on GitLab.com require Premium or Ultimate; use a personal token on
   Free unless a suitable group or service-account token is already available.
3. In GitHub, open **Settings > Secrets and variables > Actions** and add:
   - `GITLAB_USERNAME`: a non-empty GitLab username.
   - `GITLAB_TOKEN`: the access token value.
   - `GITLAB_REPO`: `namespace/project`, without `https://gitlab.com/` or `.git`.
4. Push to `main`, then inspect the **Mirror to GitLab** workflow run.
5. Compare commit IDs:

   ```sh
   git ls-remote https://github.com/zengtao227/TravelSpendPlus.git refs/heads/main
   git ls-remote https://gitlab.com/zengtao227/TravelSpendPlus.git refs/heads/main
   ```

6. Compare the release tag on both remotes with the same command and a
   `refs/tags/<tag>` ref.

The workflow force-updates and prunes GitLab branches and tags so they match
GitHub. If GitLab has diverged, first create a backup ref for any work that
must be preserved, compare the histories, move legitimate changes back to a
GitHub branch, and rerun the workflow. Never resolve divergence by making
GitLab the new development source.

## First F-Droid Submission

Current submission: `https://gitlab.com/fdroid/fdroiddata/-/merge_requests/44806`.
GitLab blocked fork CI before starting any jobs because it requested account
identity verification. The merge request records this and asks F-Droid
maintainers to trigger the authoritative upstream pipeline, as directed by the
official inclusion template.

- [x] Confirm the GitLab mirror is public and synchronized.
- [x] Point the build recipe to version `1.0.1`, code `13`, and release commit
  `6c9d3c551838cf08b85cab70df56f24ac3c35460`.
- [x] Copy the metadata into a public `fdroiddata` fork at
  `metadata/com.zengtao.travelspendplus.yml`.
- [x] Pass the official fdroidserver parser, `fdroid lint`, and automatic update
  simulation against the submitted metadata.
- [ ] Complete the authoritative F-Droid CI and isolated build checks.
- [x] Submit a merge request to the F-Droid `fdroiddata` project.
- [ ] Respond to dependency scanner, CI, and reproducibility review findings
  without adding binary exceptions unless their necessity and licensing are
  proven.

The GitLab mirror contains source branches and tags. GitHub Release APKs are not
Git objects and are not copied by the mirror workflow. They must remain on
GitHub because the F-Droid recipe downloads them as reproducible-build reference
binaries and verifies them against its source builds.

## Updating After Acceptance

1. Bump both `versionName` and the source/base code in `app/pubspec.yaml`.
2. Add changelogs for the three ABI version codes derived from that base code.
3. Run analysis, tests, and `flutter build apk --release --split-per-abi`.
4. Commit to GitHub and create the immutable `v<versionName>` tag.
5. Sign and publish all three ABI APKs, then verify the tag reaches GitLab.
6. Let the tested `VercodeOperation` auto-update create the three F-Droid build
   entries, or update the existing MR manually while it is still under review.

## Common Failure Causes

- The `v<versionName>` tag, source/base code, or ABI-derived version codes do not agree.
- The build recipe points to a branch or moving tag instead of a full commit.
- A release build is signed with a debug key.
- The repository or submodules are not publicly readable.
- A dependency contains non-free code, tracking, ads, or unreviewed native
  binaries.
- The selected Flutter/Gradle/JDK versions are unavailable or not pinned.
- Any declared ABI APK output path differs from the actual unsigned build output.
- Fastlane descriptions exceed their limits or are stored in the wrong path.
- A changelog filename does not match its Android version code.
- Screenshots or other media have unclear redistribution rights.
