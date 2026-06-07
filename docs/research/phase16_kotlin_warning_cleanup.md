# Phase 16 Kotlin Warning Cleanup

Date: 2026-06-07

## Changes

- Converted the Android host activity from Kotlin to Java.
- Removed the app module's `kotlin-android` plugin and `kotlinOptions`.
- Kept root Kotlin Gradle Plugin configuration because third-party Flutter plugins still apply KGP.
- Upgraded `file_picker` from `10.3.10` to `11.0.2`.
- Updated the local file picker call site from `FilePicker.platform.pickFiles()` to `FilePicker.pickFiles()`.

## Dependency Findings

- `device_info_plus 13.1.0` and `package_info_plus 10.1.0` require `win32 6.x`.
- Stable `file_picker 11.0.2` requires `win32 5.x`.
- Because of that conflict, `device_info_plus` and `package_info_plus` were kept on the current stable resolving line.
- `file_picker 12.0.0-beta.5` was not used.

## Verification

- `flutter pub get` succeeded.
- `flutter test` passed with 71 tests.
- `flutter analyze --no-fatal-infos` exited 0 with the existing 13 info-level lints.
- `flutter build apk --release` succeeded.
- `flutter build appbundle --release` succeeded.
- `adb install -r build/app/outputs/flutter-apk/app-release.apk` succeeded.
- Launch smoke confirmed `com.topal.iptv/com.topal.iptv.MainActivity` focused and rendered the Live root screen.

Artifacts:
- `docs/research/phase16_start.xml`

Hashes:
- APK SHA256: `C4388F284E960D72E6FA7541023AB9BDEEABECE8A6FEC5188D40CB3C6CC466F7`
- AAB SHA256: `CA398596CF1F4880BC9BC0FDC7D49B327A3BA5CCDCEC8D0ABD6AE49ABC406BA5`

## Remaining Warning

The app-owned Kotlin Gradle Plugin warning is gone. Flutter still warns that these upstream plugins apply KGP:
- `device_info_plus`
- `file_picker`
- `package_info_plus`
- `wakelock_plus`

This is an upstream plugin compatibility issue. Do not suppress it or vendor/fork plugins in this phase.
