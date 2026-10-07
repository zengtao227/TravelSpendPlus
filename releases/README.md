# Local release packages

All retained signed APKs live in `releases/<version>/` in this project. Version directories are ignored by Git; distribute APKs through GitHub Release assets instead of committing binaries.

## Version 1.1.6

- `1.1.6/TravelSpendPlus-1.1.6-legacy-update-4092.apk`: compatible update for the existing legacy-signed Samsung phone. Install over the old app to retain its data. This signing identity differs from the public release identity.
- `1.1.6/TravelSpendPlus-1.1.6+241.apk`: public release, armeabi-v7a.
- `1.1.6/TravelSpendPlus-1.1.6+242.apk`: public release, arm64-v8a.
- `1.1.6/TravelSpendPlus-1.1.6+243.apk`: public release, x86_64.

GitHub assets: https://github.com/zengtao227/TravelSpendPlus/releases/tag/v1.1.6

Keep the existing signing identity when updating a phone. Do not uninstall the app to work around a signature mismatch.

Older retained releases are stored in the neighboring version directories. `.verify.txt` files record signature validation; `.idsig` files are signing sidecars. Signing keys remain outside the project.

## Future releases

Use this project directory as the final package destination: `releases/<version>/`. After verifying hashes and uploading GitHub assets, remove temporary APK copies from Downloads, temporary signing directories, and `app/build/`. Do not remove signing keys or phone data.
