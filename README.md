# TravelSpendPlus

TravelSpendPlus is an open-source Flutter application for recording trip
expenses and comparing planned spending with actual spending.

## Features

- Create trips with dates, a home currency, and an optional total budget.
- Record planned and actual expenses.
- Organize expenses with built-in or custom categories.
- Review totals, remaining budget, and category breakdowns.
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
[`fastlane/metadata/android/`](fastlane/metadata/android/). A draft F-Droid
build recipe and the release checklist are available in [`docs/fdroid/`](docs/fdroid/)
and [`docs/fdroid-release-checklist.md`](docs/fdroid-release-checklist.md).

## Repository Policy

[GitHub](https://github.com/zengtao227/TravelSpendPlus) is the canonical
development repository and the only place where development changes should be
made. [GitLab](https://gitlab.com/zengtao227/TravelSpendPlus) is a read-only
operational mirror used for the F-Droid submission workflow.

## License

TravelSpendPlus is available under the [MIT License](LICENSE).
