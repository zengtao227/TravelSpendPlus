# GitHub → GitLab → F-Droid Release Runbook

This is the operational source of truth for maintaining and releasing
TravelSpendPlus. It is written so that Claude CLI or another maintainer can run
the workflow without rediscovering the repository topology or inventing a
second release process.

## 1. Non-negotiable repository model

```text
GitHub (development source of truth)
  ├─ push main ──> GitHub Actions ──> GitLab mirror main
  ├─ push tag  ──> GitHub Actions ──> GitLab mirror tag
  └─ GitHub Release + optional signed upstream APK

GitLab mirror source/tag ──> F-Droid builds and signs its own APK
```

| Purpose | Location | Write policy |
|---|---|---|
| Development, issues, commits, tags, releases | `https://github.com/zengtao227/TravelSpendPlus` | Canonical; write here |
| Public source mirror for F-Droid | `https://gitlab.com/zengtao227/TravelSpendPlus` | Automated mirror; do not develop here |
| F-Droid package recipe | `fdroid/fdroiddata` | Change through an F-Droid merge request |

The mirror contains Git branches and tags. GitHub Release attachments are not
Git objects, are not mirrored, and must not be manually copied to GitLab for
F-Droid. F-Droid checks out the source recipe, builds an unsigned APK, and signs
the distributed APK with the F-Droid key.

## 2. Fixed project facts

- Flutter project: `app/`
- Android application ID: `com.zengtao.travelspendplus`
- License: MIT
- Default branch: `main`
- Tag format: `v<versionName>+<versionCode>`
- Fastlane metadata: `fastlane/metadata/android/en-US/`
- Local F-Droid recipe copy:
  `docs/fdroid/com.zengtao.travelspendplus.yml`
- Mirror workflow: `.github/workflows/mirror-to-gitlab.yml`
- Current submitted release candidate: `1.0.1+14`
- Release tag: `v1.0.1+14`
- Tagged source commit: `a591b78dc537d0d11811ca35365ee3b55b5a9760`
- Current F-Droid submission:
  `https://gitlab.com/fdroid/fdroiddata/-/merge_requests/44806`

As of 2026-08-04, the F-Droid MR is open. `v1.0.1+13` (commit `6c9d3c5...`) was
the originally submitted candidate; it does not contain `fastlane/.../icon.png`
because that file was only added to `main` after the tag (tags are immutable,
so it could not be backfilled). `v1.0.1+14` is a versionCode-only bump that
includes the icon and syncs the local recipe doc with metadata fixes already
applied on the MR (`AutoUpdateMode`, dropped duplicate `Summary`/`Description`,
`--enforce-lockfile`). The `fdroiddata` MR's `Builds` entry must be updated to
point at `1.0.1+14` before it is representative of what should ship. Local
`fdroidserver 2.4.2` parsing, lint, metadata normalization, and automatic
update detection passed for `1.0.1+13`; re-verify after retargeting to
`1.0.1+14`. The GitLab fork pipeline initially showed zero jobs because GitLab
requested account identity verification (not a metadata test failure); after
fixing an unrelated `AutoUpdateMode` schema-validation failure, a full pipeline
(9/9 jobs, including `fdroid build`) has since passed against the
`1.0.1+13`/commit-`6c9d3c5` metadata still on the MR at that time. The MR has
not yet been retargeted to `1.0.1+14`/commit-`a591b78`, so that specific
combination has not itself been through CI yet — do so and re-check before
treating it as validated.

## 3. One-time configuration

### GitHub → GitLab mirror

The default free-tier implementation is GitHub Actions. These GitHub repository
secrets must exist under **Settings → Secrets and variables → Actions**:

- `GITLAB_USERNAME`: GitLab username used for HTTPS authentication.
- `GITLAB_TOKEN`: GitLab personal access token with `write_repository` scope.
- `GITLAB_REPO`: `zengtao227/TravelSpendPlus` without a URL scheme or `.git`.

Check only that the secret names exist; never print, export to logs, or commit
their values. Rotate an expired GitLab token and update `GITLAB_TOKEN` in GitHub.

The alternative for an account with GitLab Premium/Ultimate is a one-way pull
mirror under **GitLab → Settings → Repository → Mirroring repositories**. Never
enable a bidirectional workflow and never treat GitLab as the source of truth.

### Upstream GitHub APK signing

This signing identity is only for optional APKs attached to GitHub Releases.
It is unrelated to the key F-Droid uses for its repository APK.

- Keystore:
  `/Users/zengtao/Library/Application Support/TravelSpendPlus/release.keystore`
- Alias: `travelspendplus`
- Keychain service: `com.zengtao.travelspendplus.release-signing`
- Keychain account: `zengtao227`
- Certificate SHA-256:
  `B4:58:E2:3E:5A:27:33:5F:9F:72:E8:DA:EE:04:EE:B2:AD:8C:DB:12:80:32:58:02:95:0B:E1:70:A2:A3:36:03`

The keystore must have an independent encrypted backup. Never put signing
configuration, keystores, passwords, or generated signed APKs into Git.

## 4. Normal development flow

1. Work in the GitHub clone on a branch or `main`, according to the requested
   scope.
2. Inspect `git status --short` before editing and preserve unrelated changes.
3. Run tests appropriate to the change.
4. Commit and push to GitHub. The configured `origin` must remain GitHub.
5. The `Mirror to GitLab` workflow automatically force-synchronizes and prunes
   GitLab branches/tags so GitLab matches GitHub.
6. Verify the workflow and remote commit when the change is release-related.

Do not manually push routine project commits to the GitLab mirror. Do not add a
GitLab development remote as the normal push target.

## 5. Complete version-release procedure

Run commands from the repository root unless a step says otherwise.

### Step 1 — Inspect the starting state

```sh
git status --short
git branch --show-current
git remote -v
git pull --ff-only origin main
```

The branch must be `main` for the final release commit, `origin` must point to
GitHub, and unexpected local changes must be resolved without discarding user
work.

### Step 2 — Choose a new version

- Increment `versionName` using semantic versioning.
- Increment the positive integer `versionCode`; never reuse a code.
- Construct the tag as `v<versionName>+<versionCode>`.
- Confirm the tag and version code do not already exist.

Example for a hypothetical next release only:

```text
pubspec version: 1.0.2+14
tag: v1.0.2+14
changelog: fastlane/metadata/android/en-US/changelogs/14.txt
```

Do not blindly use that example if a newer version already exists.

### Step 3 — Update release-owned files

Update all of the following in one release commit:

1. `app/pubspec.yaml`: `version: <versionName>+<versionCode>`.
2. `app/lib/version.dart`: keep `kAppVersion` exactly synchronized.
3. `fastlane/metadata/android/en-US/changelogs/<versionCode>.txt`.
4. Store descriptions/screenshots only when the user-visible behavior changed.
5. Any code or documentation intended to be part of the tagged source.

Public-facing text should be English. Chinese localization resources, test
fixtures, and historical/internal documents may remain Chinese. Do not perform
a repository-wide translation merely for appearance.

### Step 4 — Audit F-Droid compatibility

Confirm before every release:

- `applicationId` is still `com.zengtao.travelspendplus`.
- `release` does not use `signingConfigs.debug` or a committed private key.
- Root `LICENSE` remains MIT.
- Source and submodules are publicly readable.
- No new Firebase, Google Play Services, Crashlytics, analytics, advertising,
  proprietary tracking, or unexplained prebuilt binary dependencies were added.
- `sqlite3_flutter_libs` remains absent unless a future, documented decision
  explicitly changes this.
- Screenshots are redistributable, show real UI, contain no personal data, and
  have no debug banner.

Useful searches:

```sh
rg -n "applicationId|signingConfig|signingConfigs" app/android
rg -n -i "firebase|google[-_ ]?services|crashlytics|analytics|admob|appsflyer" app
rg -n "sqlite3_flutter_libs" app/pubspec.yaml app/pubspec.lock
```

Review results rather than treating every textual match as a dependency.

### Step 5 — Run the release gate

```sh
cd app
flutter pub get
flutter analyze
flutter test
flutter build apk --release
cd ..
```

Required evidence:

- analysis exits successfully with no issues;
- all tests pass;
- the APK exists at
  `app/build/app/outputs/flutter-apk/app-release.apk`;
- Android package, version name, and version code match the intended release.

Use Android build tools to inspect the artifact:

```sh
aapt dump badging app/build/app/outputs/flutter-apk/app-release.apk
apksigner verify --verbose app/build/app/outputs/flutter-apk/app-release.apk
```

The public build is expected to be unsigned. It must not be debug-signed.

### Step 6 — Commit and push GitHub `main`

Review the exact diff and add only intentional files:

```sh
git diff --check
git status --short
git add <explicit-release-files>
git commit -m "feat: prepare <versionName> F-Droid release"
git push origin main
```

Do not use `git add -A` when unrelated files are present. Do not create the tag
until every source, metadata, and changelog file intended for the release is in
this commit.

### Step 7 — Verify the `main` mirror

Wait for **GitHub Actions → Mirror to GitLab** to succeed, then compare:

```sh
git ls-remote https://github.com/zengtao227/TravelSpendPlus.git refs/heads/main
git ls-remote https://gitlab.com/zengtao227/TravelSpendPlus.git refs/heads/main
```

Both hashes must equal the local release commit. A failed or missing mirror is
a release blocker.

### Step 8 — Create and mirror the immutable tag

```sh
git tag -a "v<versionName>+<versionCode>" -m "TravelSpendPlus <versionName>"
git push origin "v<versionName>+<versionCode>"
git rev-list -n 1 "v<versionName>+<versionCode>"
```

Wait for the tag-triggered mirror workflow. Compare the tag and its peeled
commit on both hosts:

```sh
git ls-remote https://github.com/zengtao227/TravelSpendPlus.git "refs/tags/v<versionName>+<versionCode>*"
git ls-remote https://gitlab.com/zengtao227/TravelSpendPlus.git "refs/tags/v<versionName>+<versionCode>*"
```

The F-Droid `Builds.commit` value must be the full 40-character source commit,
not the annotated tag-object hash. Never move the tag after publication. A
later docs-only commit on `main` is allowed but must not retag the release.

### Step 9 — Optionally sign an upstream GitHub APK

F-Droid does not need this artifact. If publishing an upstream APK, work on a
copy outside the repository and keep the public build configuration unsigned.
Locate `zipalign` and `apksigner` in the installed Android SDK build-tools
directory, then use a release-specific temporary directory.

Retrieve the password from Keychain without printing it, export it only for the
signing process, and clear it afterwards:

```sh
RELEASE_STORE_PASSWORD="$(security find-generic-password -s com.zengtao.travelspendplus.release-signing -a zengtao227 -w)"
export RELEASE_STORE_PASSWORD

zipalign -p -f 4 <unsigned-apk-copy> <aligned-apk>
apksigner sign \
  --ks "/Users/zengtao/Library/Application Support/TravelSpendPlus/release.keystore" \
  --ks-key-alias travelspendplus \
  --ks-pass env:RELEASE_STORE_PASSWORD \
  --key-pass env:RELEASE_STORE_PASSWORD \
  <aligned-apk>

apksigner verify --verbose --print-certs <aligned-apk>
shasum -a 256 <aligned-apk>
unset RELEASE_STORE_PASSWORD
```

The certificate fingerprint must match the value in section 3. Do not publish
an unsigned or debug-signed APK as the upstream release asset.

### Step 10 — Publish the GitHub Release

Create factual release notes from the changelog and attach only the verified
signed APK when one is being offered:

```sh
gh release create "v<versionName>+<versionCode>" <signed-apk> \
  --title "TravelSpendPlus <versionName>" \
  --notes "<concise factual release notes>"
gh release view "v<versionName>+<versionCode>"
```

Do not create a GitLab Release solely for F-Droid and do not upload this APK to
GitLab as part of the mirror workflow.

## 6. F-Droid metadata workflow

### First inclusion — current state

The initial recipe is already submitted in MR !44806. Do not open a duplicate
submission. Monitor that MR, answer reviewer findings with evidence, and keep
the source tag immutable. The remaining authoritative CI/build and merge are
controlled by F-Droid maintainers.

If the recipe must change before merge:

1. Modify `docs/fdroid/com.zengtao.travelspendplus.yml` on GitHub first when the
   change should remain documented in this project.
2. Validate it in a disposable clone of `fdroiddata`.
3. Update the existing MR branch, not a second MR.
4. Confirm the submitted file contains exactly one package recipe and did not
   acquire duplicate blocks through a web editor.

Representative validation in a disposable `fdroiddata` checkout:

```sh
cp docs/fdroid/com.zengtao.travelspendplus.yml <fdroiddata>/metadata/com.zengtao.travelspendplus.yml
cd <fdroiddata>
fdroid lint com.zengtao.travelspendplus
fdroid rewritemeta com.zengtao.travelspendplus
fdroid checkupdates --auto com.zengtao.travelspendplus
```

`rewritemeta` and `checkupdates --auto` may modify files, so run them only in a
disposable checkout and inspect the diff. An isolated `fdroid build
com.zengtao.travelspendplus:<versionCode>` is the strongest local preflight when
the official build environment is available.

### Updates after F-Droid acceptance

The recipe currently uses:

```yaml
AutoUpdateMode: Version
UpdateCheckMode: Tags
```

`AutoUpdateMode` briefly used the invalid value `Version v%v+%c`, which fails
fdroidserver's schema regex (`^(None|Version( \+.+)?)$`); it was corrected to
plain `Version` since `UpdateCheckData` already resolves the version from
`pubspec.yaml`. Do not reintroduce a `%v`/`%c` template into this field.

For a normal future release:

1. Complete sections 4 and 5 of this runbook.
2. Ensure the new immutable tag is visible on the GitLab mirror.
3. Watch the official F-Droid metadata/update automation.
4. Let the bot create the new build entry when it recognizes the tag.
5. Submit a focused `fdroiddata` MR only if the automatic update fails or the
   build recipe itself must change.

Do not edit the official F-Droid metadata merely to upload the GitHub APK;
F-Droid always builds from source.

## 7. Divergence and failure handling

### GitLab mirror diverged

1. Stop writing to GitLab.
2. Identify any GitLab-only commits and create a backup ref before overwriting
   anything that may matter.
3. Move legitimate work to a GitHub branch and review it there.
4. Rerun the mirror workflow so GitLab again matches GitHub.
5. Never change the workflow direction or make GitLab the new canonical repo.

### Mirror workflow failed

- Confirm all three GitHub secret names exist.
- Confirm the token is valid and has `write_repository` only.
- Confirm `GITLAB_REPO` is exactly `zengtao227/TravelSpendPlus`.
- Check GitLab branch protection and token permissions.
- Do not print the remote URL after credentials have been embedded in it.

### F-Droid build failed

- Compare tag, `versionName`, `versionCode`, and full source commit.
- Confirm `subdir: app` and the APK output path.
- Check the pinned Flutter srclib version and Gradle/JDK compatibility.
- Review scanner output for new binaries or non-free dependencies.
- Reproduce in an isolated official environment before changing exceptions.
- Never add a broad scanner exception merely to make CI green.

## 8. Definition of done

A release is operationally complete only when all of these are true:

- release-owned files are committed on GitHub `main`;
- Flutter analysis, tests, and release build pass;
- GitHub and GitLab `main` point to the same release commit;
- the immutable tag exists on both hosts and resolves to the same source commit;
- any GitHub APK is release-signed and fingerprint-verified;
- the GitHub Release is published with accurate notes;
- F-Droid metadata recognizes the same version/code/commit;
- F-Droid review status and external blockers are reported honestly;
- the private signing key remains outside Git and has a secure backup;
- the worktree is clean or contains only clearly identified user-owned work.

F-Droid publication itself is complete only after F-Droid CI, reviewer approval,
merge, build, signing, and repository indexing finish. Opening an MR is a
successful submission, not proof that the app is already available in F-Droid.
