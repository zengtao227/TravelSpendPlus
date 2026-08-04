# Claude CLI Instructions

Before changing or releasing this project, read:

1. `README.md`
2. `docs/github-gitlab-fdroid-release-runbook.md`
3. `docs/fdroid-release-checklist.md`

## Repository Contract

- GitHub is the only canonical development repository:
  `https://github.com/zengtao227/TravelSpendPlus`.
- GitLab is a public operational mirror for F-Droid:
  `https://gitlab.com/zengtao227/TravelSpendPlus`.
- Make, commit, tag, and push project changes on GitHub only.
- Never make an independent development commit on the GitLab mirror.
- Never force-push GitHub. The mirror workflow may force-update GitLab so it
  remains an exact copy of GitHub.
- Release tags are immutable. Never move or reuse an existing tag or Android
  version code.
- GitHub Release APK assets are not mirrored to GitLab and are not required by
  F-Droid. F-Droid builds and signs from the mirrored source.

## Release Safety

- Preserve unrelated worktree changes and inspect `git status` before editing.
- Keep the Android application ID `com.zengtao.travelspendplus`.
- Keep Android release signing out of the public Gradle configuration. F-Droid
  must receive an unsigned source build and signs its own APK.
- If publishing an upstream APK on GitHub, sign only a copied artifact with the
  private keystore stored outside the repository. Never expose the keystore,
  password, GitLab token, or GitHub secrets.
- Do not add Firebase, Google Play Services, Crashlytics, analytics, advertising,
  or other proprietary SDKs without first reassessing F-Droid eligibility.
- Public-facing README, store copy, changelogs, and screenshots should use
  English. Do not mass-translate localization resources, tests, or historical
  design documents merely to remove Chinese text.

## Required Release Gate

For every release, update both `app/pubspec.yaml` and `app/lib/version.dart`, add
the version-code changelog, run Flutter analysis/tests/release build, push
GitHub `main`, verify the GitLab mirror, create and push the immutable tag, and
verify the tag on both hosts. Follow the exact commands and F-Droid steps in the
runbook.

Routine in-scope checks, edits, commits, pushes, and release verification should
be completed without repeatedly asking for confirmation when the user has
already authorized the release. Stop only for platform-enforced authentication,
unexpected destructive actions, secret exposure risk, or a decision that would
change the repository contract.
