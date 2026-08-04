# TravelSpendPlus Flutter App

This directory contains the Flutter application for TravelSpendPlus. The
canonical project documentation, release instructions, and license are in the
[repository root](../README.md).

## Development

```sh
flutter pub get
flutter run
```

## Verification and Android Build

```sh
flutter analyze
flutter test
flutter build apk --release
```

The public Android project intentionally contains no private release keystore.
F-Droid builds and signs its own APK from the tagged source.
