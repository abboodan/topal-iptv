# Phase 14 Built-in Kotlin and Signing Notes

Date: 2026-06-07

## Signing Gate

- Added release signing config that reads `android/key.properties` only if the file exists.
- Added `android/key.properties.example` with placeholder values only.
- `android/key.properties` and `*.jks` remain ignored by `.gitignore`.
- No keystore was generated and no signing secrets were stored.
- With no `android/key.properties`, release APK builds still use debug signing for local testing.

## Built-in Kotlin Gate

Attempted:
- Gradle wrapper `9.1.0`
- Android Gradle Plugin `9.0.1`
- Removed explicit Kotlin Gradle Plugin from `settings.gradle`
- Removed `kotlin-android` from the app Gradle plugins
- Set `android.builtInKotlin=true`
- Set `android.newDsl=true`

Result:
- `flutter test` passed.
- `flutter analyze --no-fatal-infos` exited 0 with the existing 13 info-level lints.
- `flutter build apk --release` failed while applying `dev.flutter.flutter-gradle-plugin`.
- Flutter reported that AGP 9+ only reads the new DSL interface and the current Flutter Gradle plugin failed under that path.

Decision:
- Built-in Kotlin migration was rolled back.
- Signing config was preserved.
- The remaining Built-in Kotlin warning is documented as a Flutter/AGP9 compatibility blocker for the current Flutter 3.44.1 environment.

## App Bundle Gate

`flutter build appbundle --release` failed before Built-in Kotlin migration due to native debug symbol stripping.

Local toolchain evidence:
- Flutter doctor reports Android cmdline-tools missing.
- `C:\Users\xr-us\AppData\Local\Android\Sdk\ndk\28.2.13676358\toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-strip.exe` is 0 bytes.

Decision:
- AAB packaging is blocked by local Android SDK/NDK repair, not by the signing config.

## Final APK and ADB Smoke

Final stable Android toolchain after rollback:
- AGP `8.13.2`
- Gradle wrapper `8.14.3`
- Kotlin Gradle Plugin `2.2.21`
- NDK `28.2.13676358`

Verification:
- `flutter test` passed with 71 tests.
- `flutter analyze --no-fatal-infos` exited 0 with the existing 13 info-level lints.
- `flutter build apk --release` succeeded.
- `adb install -r build/app/outputs/flutter-apk/app-release.apk` succeeded.
- Final APK SHA256: `F49F3EFC45E24D6101917D6649D14C52F19C832EE037B471C29254E6BF0C9CFD`.

ADB smoke:
- Confirmed `mCurrentFocus` was `com.topal.iptv/com.topal.iptv.MainActivity` before navigation checks.
- App start opened Topal IPTV, not Chrome or another foreground package.
- Live All scroll rendered rows.
- Live EPG rendered clean no-data rows for channels without short EPG.
- Movie detail opened and showed the Play action.
- Series detail rendered metadata and episode rows.
- Tapping an episode opened landscape playback.
- Back returned from playback to the Series detail page.
- After the final APK reinstall, launching `com.topal.iptv/.MainActivity` focused Topal and rendered the Live root screen.

Artifacts:
- `docs/research/phase14_final_smoke/01_start.*`
- `docs/research/phase14_final_smoke/02_live_all.*`
- `docs/research/phase14_final_smoke/03_live_epg.*`
- `docs/research/phase14_final_smoke/04_movies_all.*`
- `docs/research/phase14_final_smoke/05_movie_detail.*`
- `docs/research/phase14_final_smoke/06_series_all.*`
- `docs/research/phase14_final_smoke/07_series_episodes.*`
- `docs/research/phase14_final_smoke/08_episode_player.*`
- `docs/research/phase14_final_smoke/09_back_series.xml`
- `docs/research/phase14_final_smoke/10_final_start.xml`
