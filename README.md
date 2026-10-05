# TravelSpendPlus

TravelSpendPlus is an open-source Flutter application for recording trip
expenses and comparing planned spending with actual spending.

## Features

- Create trips with dates, a home currency, and an optional total budget.
- Record planned and actual expenses.
- Organize expenses with built-in or custom categories.
- Review totals, remaining budget, and category breakdowns.
- Group expenses by day, with the newest dates and entries first.
- Optionally spread an expense over its inclusive date range. Daily amounts
  preserve the original total; actual daily averages count only shares through
  today. Enable this option when entering a flight or accommodation cost and
  choose the days it covers. On upgrade or legacy backup restore, existing
  multi-day date ranges automatically use daily allocation; single-day entries
  stay on their original day.
- Tap a chart category or location to review its matching expenses.
- Enter exchange rates manually or request an optional live reference rate.
- Attach trip and expense photos.
- Back up and restore trip data as JSON, and export a trip as CSV.

## Technology

The application is built with Flutter and Dart. Android is the distribution
target for F-Droid; the Flutter project itself is located in [`app/`](app/).

## Run Locally

Install a Flutter stable SDK compatible with the version recorded in
[`app/.metadata`](app/.metadata), then run:

```sh
cd app
flutter pub get
flutter run
```

## Build for Android

Run the following from the repository root:

```sh
cd app
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Release signing is intentionally not configured in the public repository.
F-Droid builds and signs its distributed APK. Maintainers publishing through
another channel must configure a private release keystore outside version
control and must never commit keystore files or passwords.

## F-Droid

Store metadata is maintained under
[`fastlane/metadata/android/`](fastlane/metadata/android/). A project copy of
the submitted F-Droid build recipe and the release checklist are available in
[`docs/fdroid/`](docs/fdroid/) and
[`docs/fdroid-release-checklist.md`](docs/fdroid-release-checklist.md). The
complete GitHub-to-GitLab-to-F-Droid operating procedure is documented in the
[`release runbook`](docs/github-gitlab-fdroid-release-runbook.md).

## Repository Policy

[GitHub](https://github.com/zengtao227/TravelSpendPlus) is the canonical
development repository and the only place where development changes should be
made. [GitLab](https://gitlab.com/zengtao227/TravelSpendPlus) is a read-only
operational mirror used for the F-Droid submission workflow.

## License

TravelSpendPlus is available under the [MIT License](LICENSE).
