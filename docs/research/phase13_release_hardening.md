# Phase 13 Release Hardening Notes

Date: 2026-06-07

## Android Build Tooling

- Flutter: `3.44.1`
- Android Gradle Plugin: `8.13.2`
- Gradle wrapper: upgraded from `8.13` to `8.14.3`
- Kotlin Gradle Plugin: upgraded from `2.1.0` to `2.2.21`
- Android NDK: pinned to `28.2.13676358`

## Gate Results

- Baseline before edits:
  - `flutter test`: passed with 71 tests
  - `flutter analyze --no-fatal-infos`: exited 0 with existing 13 info-level lints
  - `flutter build apk --release`: passed with Gradle/Kotlin/NDK warnings
- Kotlin `2.2.21` gate:
  - Tests, analyze, and release build passed
  - Kotlin-version warning disappeared
- Gradle `8.14.3` gate:
  - Tests and analyze passed
  - First release build hit a stale R8 file-lock on `classes.dex`
  - After stopping stale Gradle/Kotlin daemons, the same release build passed
  - Gradle-version warning disappeared
- NDK `28.2.13676358` gate:
  - Tests, analyze, and release build passed
  - NDK mismatch warning disappeared

## Remaining Warning

Flutter still warns that the app and some plugins apply Kotlin Gradle Plugin instead of using Built-in Kotlin. That migration is intentionally deferred because it is broader than this phase's safe version upgrades.

## Final APK

- Path: `build/app/outputs/flutter-apk/app-release.apk`
- Size: 97.3 MB
- SHA256: `F5796C3055D09391480C010300BE1B7BFA2783599BDC09C9A6F40DBEFDCBF30F`
- `adb install -r build/app/outputs/flutter-apk/app-release.apk`: succeeded

## Final ADB Smoke

Artifacts are stored in `docs/research/phase13_final_smoke/`:
- `01_start.*`
- `02_live_all.*`
- `03_live_epg.*`
- `04_movies_all.*`
- `05_movie_detail.*`
- `06_series_all.*`
- `07_series_detail.*`
- `08_series_episodes.*`
- `09_episode_player.*`
- `10_back_series.xml`

Confirmed:
- Topal package focus before smoke captures: `com.topal.iptv/.MainActivity`
- Live All scroll rendered after install
- Live EPG rows rendered
- Movie detail opened and showed Play
- Series detail opened with metadata
- Episodes rendered, an episode opened the player route, and Back returned to Series detail
