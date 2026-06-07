# Topal IPTV Professionalization Roadmap

Date: 2026-06-06

## Goal

Bring Topal IPTV from the current raw Flutter baseline to a professional, fluid IPTV app that matches or exceeds the observed Zen Player experience, while preserving working playback/import behavior and executing one small phase at a time.

## Operating Rules

- Execute one micro-phase per user confirmation.
- Do not bundle shell, data, details, player, and EPG work into one refactor.
- Before each phase, restate the exact scope and files expected to change.
- After each phase, stop and report verification evidence.
- Update the relevant `docs/*.md` memory file when architecture or behavior changes.
- Preserve existing source setup, search, favorites, history, resume, TV mode, and playback unless the phase explicitly changes them.
- Prefer slivers, builders, fixed item extents, stable keys, and small rebuild scopes.
- Keep 60 fps as the baseline target and avoid choices that block 120 fps on capable devices.
- Use ADB smoke testing on the established device for user-visible phases.
- Do not start the next phase until the user approves.

## Phase 0: Baseline Research and Documentation

Status: completed in this thread.

Outputs:
- `docs/adb_ux_research.md`
- `docs/architecture_state.md`
- `docs/ui_components.md`
- `docs/data_layer.md`
- `docs/implementation_roadmap.md`
- ADB screenshots and UI dumps in `docs/research/`

Done criteria:
- Zen Player UX flow captured.
- Topal baseline captured.
- Current Flutter codebase mapped.
- Roadmap written for approval.

## Phase 1: Core Mobile Navigation Shell

Goal:
- Make mobile navigation media-first without replacing the data layer.

Status:
- Completed in this thread.

Expected files:
- Created `lib/models/mobile_section.dart`
- Created `lib/mobile_shell_nav.dart`
- Modified `lib/home.dart`
- Modified `lib/settings_view.dart`
- Added `test/mobile_shell_nav_test.dart`
- Updated docs after completion

Scope:
- Add primary mobile destinations: Live, Movies, Series.
- Keep Favorites, History, Search, and Settings accessible without making them the primary mental model.
- Continue using existing `Filters.mediaTypes` and `ViewType` under the hood.
- Preserve current TV mode untouched.

Implemented behavior:
- Bottom navigation now shows Live, Movies, Series, Settings.
- Live, Movies, and Series map to one `MediaType` and use `ViewType.categories` as the section root.
- Browse, All, Favorites, and History remain accessible as secondary chips under search.
- Search hint changes by active section.
- Settings uses the same media-first bottom shell.
- Follow-up fix completed: typing a query in Browse searches media items within the active section instead of category rows.
- Follow-up fix completed: `All media` chip searches enabled Live, Movies, and Series together and shows result type labels.

Out of scope:
- VOD detail pages
- Series detail pages
- Player controls
- EPG
- Data model changes

Verification:
- `flutter analyze`
- Android build or debug install
- ADB smoke test for Live, Movies, Series, Search, Settings, and Back.

Verification completed:
- `flutter test` passed after the search fix.
- `flutter analyze --no-fatal-infos` exited 0. The project still reports existing info-level lints outside Phase 1.
- `flutter build apk --release` succeeded.
- `adb install -r build/app/outputs/flutter-apk/app-release.apk` succeeded.
- ADB smoke test confirmed Live, Movies, Series, and Settings selected states in UIAutomator dumps.
- ADB smoke test confirmed Movies search returns movie rows, Series search returns series rows, and `All media` search returns typed mixed-media rows.

Stop point:
- Stop here and ask for approval before Phase 2.

## Phase 2: Media-Aware Browsing Surfaces

Goal:
- Replace the one-size-fits-all list presentation with media-aware browsing screens.

Status:
- Completed in this thread.

Expected files:
- Created `lib/models/browse_layout.dart`
- Modified `lib/home.dart`
- Modified `lib/channel_tile.dart`
- Added `test/media_browse_layout_test.dart`

Scope:
- Live: dense channel/category list.
- Movies: poster grid or rails using existing image/name fields.
- Series: poster cards using existing series root rows.
- Empty/loading/error states per media mode.
- Keep existing SQL pagination.

Implemented behavior:
- `Browse` continues to show category rows for the active section.
- `All` shows a flat list of items inside the active section:
  - Live: dense channel rows.
  - Movies: poster grid.
  - Series: poster grid.
- `All media` keeps a mixed row layout with media type labels.
- Empty states now describe the active mode, such as no categories, channels, movies, series, or media.
- Layout selection is isolated in `BrowseLayout` so later phases can adjust density without touching SQL behavior.

Out of scope:
- New metadata import
- Detail pages
- Player changes

Verification:
- Scroll large categories on device.
- Confirm no layout overflow in portrait/landscape.
- Confirm memory usage is reasonable through image cache sizing and fixed dimensions.

Verification completed:
- `flutter test` passed.
- `flutter analyze --no-fatal-infos` exited 0. Existing info-level lints remain outside this phase.
- `flutter build apk --release` succeeded.
- `adb install -r build/app/outputs/flutter-apk/app-release.apk` succeeded.
- ADB smoke test confirmed:
  - Live `Browse` shows categories.
  - Live `All` shows channel rows.
  - Movies `Browse` shows movie categories.
  - Movies `All` shows movie poster cards.
  - Series `Browse` shows series categories.
  - Series `All` shows series poster cards.
- Phase screenshots and UI dumps are stored under `docs/research/topal_phase2_*`.

Stop point:
- Review UX density and card sizes before detail pages.

## Phase 3: VOD Detail Page V1

Goal:
- Stop opening movies directly into playback and add a professional movie detail page using currently available data.

Status:
- Completed in this thread.

Expected files:
- Created `lib/movie_detail.dart`
- Modified `lib/channel_tile.dart`
- Added `test/movie_detail_test.dart`
- Reuse `Player`

Scope:
- Poster/backdrop-style layout using available image.
- Start/resume action.
- Favorite action.
- Basic title/category/source context if available.
- Continue movie resume position.

Implemented behavior:
- Tapping a movie opens `MovieDetailPage` instead of opening `Player` immediately.
- Existing series episodes, which are stored as `MediaType.movie` with a `seriesId`, continue opening `Player` directly until the Series detail phase.
- The detail page shows poster art, title, Movie/category chips, favorite toggle, and a primary Play/Resume action.
- If a saved position exists, the primary action displays `Resume mm:ss` and a secondary `Start over` action is shown.
- Play and Resume reuse the existing `Player`, history write, HTTP header handling, and resume storage.
- Follow-up fix completed: removed the duplicate image section under the Play button so the poster is rendered once in the header.

Out of scope:
- Full Xtream VOD metadata import
- Related content rails
- Custom VOD player controls

Verification:
- Open movie detail from Movies and Search.
- Start playback.
- Exit and confirm resume still works.

Verification completed:
- `flutter test` passed with 14 tests after the duplicate-poster regression test was added.
- `flutter analyze --no-fatal-infos` exited 0. Existing info-level lints remain outside this phase.
- `flutter build apk --release` succeeded.
- `adb install -r build/app/outputs/flutter-apk/app-release.apk` succeeded.
- ADB smoke test confirmed Movies > All opens `MovieDetailPage`, the Play button is visible in the first viewport, Play opens the player route, and Back returns to the detail page.
- Phase screenshots and UI dumps are stored under `docs/research/topal_phase3_*`.

Stop point:
- Approve detail layout before metadata expansion.

## Phase 4: Series Detail Page V1

Goal:
- Convert raw series episode navigation into a show detail page with season/episode structure.

Status:
- Completed in this thread.

Expected files:
- Created `lib/series_detail.dart`
- Modified `lib/channel_tile.dart`
- Added `test/series_detail_test.dart`
- Reused `getEpisodes()` initially

Scope:
- Show header using existing image/name.
- Lazy load episodes with visible loading state.
- Group episodes by season.
- Episode rows with thumbnail/title and play action.
- Preserve current episode storage as `MediaType.movie` with `seriesId`.

Implemented behavior:
- Tapping a top-level series now opens `SeriesDetailPage` instead of navigating into a raw nested `Home` node.
- `SeriesDetailPage` refreshes episodes once per runtime when needed, using the existing `refreshedSeries` guard and `getEpisodes()` flow.
- Episodes are queried from SQLite as `MediaType.movie` rows with the selected `seriesId`.
- Episodes are grouped by inferred season labels from names such as `S01`, `Season 1`, and `1x05`.
- If no season can be inferred, episodes fall back to a single `Episodes` group.
- Episode rows show thumbnail/title and open the existing `Player` through the same settings and history flow used elsewhere.
- Loading, empty, and error states are visible inside the detail page.
- Top-level movies still open `MovieDetailPage`; live channels and episode rows still open `Player`.

Out of scope:
- Cast/genre metadata
- Full series info persistence
- Custom episode player controls

Verification:
- Open a series.
- Confirm episodes load once and persist.
- Play an episode and return.

Verification completed:
- `flutter test` passed with 17 tests.
- `flutter analyze --no-fatal-infos` exited 0. Existing info-level lints remain outside this phase.
- `flutter build apk --release` succeeded.
- `adb install -r build/app/outputs/flutter-apk/app-release.apk` succeeded.
- ADB smoke test confirmed Series > All opens `SeriesDetailPage`, episode groups render under `Season 1`, tapping an episode opens the video player, and Back returns to the detail page.
- Phase screenshots and UI dumps are stored under `docs/research/topal_phase4_*`.

Stop point:
- Approve series detail before richer metadata work.

## Phase 5: Live Browsing V1

Goal:
- Make Live TV feel intentional before player changes.

Status:
- Completed in this thread.

Expected files:
- Created `lib/live_browse.dart`
- Modified `lib/home.dart`
- Added `test/live_browse_test.dart`

Scope:
- Favorites empty state with browse action.
- Category chips/tabs or a performant equivalent.
- Dense live channel rows.
- Keep existing category/group SQL.

Implemented behavior:
- The root Live screen now shows a compact `LiveBrowseHeader` below the search/filter chips.
- In `Browse`, the header explains category browsing and provides an `All channels` action.
- In `All`, the header explains dense live scanning and provides a `Categories` action.
- Favorites and History modes get live-specific header copy without changing the existing chip model.
- Empty Live Favorites now offers a `Browse live channels` action that routes back to category browsing.
- The existing dense live row layout from Phase 2 remains unchanged.
- Live playback still opens the existing `Player`; no player, SQL, or import behavior was changed.

Out of scope:
- EPG grid
- Live channel drawer inside player
- Source-version picker

Verification:
- Navigate large live category set.
- Open channel from category.
- Return without losing context where possible.

Verification completed:
- `flutter test` passed with 21 tests.
- `flutter analyze --no-fatal-infos` exited 0. Existing info-level lints remain outside this phase.
- `flutter build apk --release` succeeded.
- `adb install -r build/app/outputs/flutter-apk/app-release.apk` succeeded.
- ADB smoke test confirmed the Live root header appears without overlap, `All channels` switches to dense live rows, opening a live channel still reaches `Player`, and Back returns to `All channels`.
- Phase screenshots and UI dumps are stored under `docs/research/topal_phase5_*`.

Stop point:
- Approve Live browsing before player overlay work.

## Phase 6: Player Architecture Split

Goal:
- Prepare player UI for custom live and VOD overlays without changing playback internals.

Status:
- Completed in this thread.

Expected files:
- Modified `lib/player.dart`
- Created `lib/player_controls/player_control_profile.dart`
- Created `lib/player_controls/material_player_controls.dart`
- Added `test/player_control_profile_test.dart`
- Added `test/player_material_controls_test.dart`

Scope:
- Separate live vs non-live control configuration.
- Keep `media_kit` player lifecycle intact.
- Preserve HTTP headers, low latency, retry, fullscreen, and resume.
- Add tests or targeted manual QA notes for lifecycle paths.

Implemented behavior:
- `PlayerControlProfile` now maps media type to either `live` or `vod` player behavior.
- Live profile disables seek bar, seek gestures, and double-tap seek; it keeps reconnect-on-completion enabled and does not save resume position.
- VOD profile keeps seek controls enabled and preserves resume restore/save behavior.
- `material_player_controls.dart` now builds the current Material controls from a profile and action callbacks.
- `Player` still owns `media_kit` player/controller lifecycle, HTTP headers, low-latency setup, fullscreen entry/exit, reconnect, and resume persistence.
- No new visual player features were added in this phase.

Out of scope:
- Full Zen-like controls
- Channel drawer
- EPG

Verification:
- Live playback works.
- Movie playback works.
- Series episode playback works.
- Resume still saves.
- Orientation/back behavior checked by ADB.

Verification completed:
- `flutter test` passed with 26 tests.
- `flutter analyze --no-fatal-infos` exited 0. Existing info-level lints remain outside this phase.
- `flutter build apk --release` succeeded.
- `adb install -r build/app/outputs/flutter-apk/app-release.apk` succeeded.
- ADB smoke test confirmed Live playback opens and returns to browsing.
- ADB smoke test confirmed Movie detail opens the VOD player route; the selected stream remained on loading during the capture.
- ADB smoke test confirmed Series detail opens an episode and video renders after the player split.
- Phase screenshots are stored under `docs/research/topal_phase6_*`.

Stop point:
- Approve split before adding features to controls.

## Phase 7: VOD Player Controls V1

Goal:
- Upgrade movie/episode controls to feel media-aware.

Status:
- Completed in this thread.

Expected files:
- Modified `lib/player_controls/material_player_controls.dart`
- Modified `lib/player.dart`
- Created `lib/player_controls/vod_transport.dart`
- Updated `test/player_material_controls_test.dart`
- Added `test/vod_transport_test.dart`

Scope:
- Clear title display.
- Timeline and duration.
- Restart action.
- Skip back/forward controls.
- Resume/start behavior remains intact.

Implemented behavior:
- VOD and series episode controls now show `Back 10 seconds`, `Restart`, and `Forward 10 seconds`.
- Live controls remain unchanged and do not show VOD transport buttons.
- VOD skip targets are clamped so backward skip cannot go before zero and forward skip cannot exceed known duration.
- Restart seeks to `Duration.zero` and resumes playback.
- Existing subtitles, audio, aspect ratio, title, timeline, and resume behavior are preserved.

Out of scope:
- Full metadata synopsis overlay unless already available.
- Live controls.

Verification:
- Scrub, pause, skip, restart, exit, resume.
- Test both movie and series episode.

Verification completed:
- `flutter test` passed with 29 tests.
- `flutter analyze --no-fatal-infos` exited 0. Existing info-level lints remain outside this phase.
- `flutter build apk --release` succeeded.
- `adb install -r build/app/outputs/flutter-apk/app-release.apk` succeeded.
- ADB smoke test confirmed VOD episode playback shows the new back 10, restart, and forward 10 controls.
- ADB smoke test confirmed Live playback still shows only subtitles, audio, and aspect controls.
- Phase screenshots are stored under `docs/research/topal_phase7_*`.

Stop point:
- Approve VOD controls before Live player overlay.

## Phase 8: Live Player Controls V1

Goal:
- Add the core live-player experience missing from Topal.

Status:
- Completed in this thread.

Expected files:
- Modified `lib/player_controls/material_player_controls.dart`
- Modified `lib/player.dart`
- Modified `lib/channel_tile.dart`
- Modified `lib/home.dart`
- Created `lib/player_controls/live_channel_context.dart`
- Added `test/live_channel_context_test.dart`
- Updated `test/player_material_controls_test.dart`

Scope:
- Live-specific overlay layout.
- Channel title and current category context.
- Channel up/down or drawer entry point.
- Sleep timer if simple and isolated.
- Clear back/close behavior.

Implemented behavior:
- Live controls now show a red `LIVE x / y` badge when the channel was opened from a loaded live list.
- The loaded live list is passed from `Home` through `ChannelTile` into `Player` using `LiveChannelContext`.
- Live controls now show previous/next channel buttons alongside existing subtitles, audio, and aspect controls.
- Previous/next channel switching updates the current channel inside the same `Player` route and writes the switched channel to history.
- VOD controls from Phase 7 remain unchanged.

Out of scope:
- Full EPG overlay
- Source-version picker
- Complex timeshift controls
- Full live channel drawer; this phase adds previous/next controls only.

Verification:
- Open live channel from category.
- Switch channel if drawer is included.
- Exit and return to browsing context.
- Confirm no VOD regressions.

Verification completed:
- `flutter test` passed with 32 tests.
- `flutter analyze --no-fatal-infos` exited 0. Existing info-level lints remain outside this phase.
- `flutter build apk --release` succeeded.
- `adb install -r build/app/outputs/flutter-apk/app-release.apk` succeeded.
- ADB smoke test confirmed Live playback opens and the overlay shows the `LIVE x / y`, previous channel, and next channel controls.
- The next-channel action is covered by `LiveChannelContext` and Material controls tests; manual ADB tapping was not reliable because this device reports portrait input coordinates while fullscreen video screenshots are landscape.
- VOD regressions are covered by the existing VOD controls tests.

Stop point:
- Approve before source-version picker or EPG.

## Phase 9: Source Variant Handling

Goal:
- Support Zen-like stream version selection when duplicate or equivalent streams exist.

Status:
- Completed in this thread.

Expected files:
- Modified `lib/backend/db_factory.dart`
- Modified `lib/backend/sql.dart`
- Modified `lib/models/channel.dart`
- Modified `lib/models/channel_preserve.dart`
- Created `lib/channel_variant_picker.dart`
- Modified `lib/channel_tile.dart`
- Modified `lib/movie_detail.dart`
- Modified `lib/series_detail.dart`
- Added `test/channel_variant_test.dart`
- Added `test/channel_variant_picker_test.dart`

Scope:
- Investigate whether current unique `(name, source_id)` blocks duplicate variants.
- Design a minimal compatible schema/query change if needed.
- Add remembered choice only after duplicates can be represented safely.

Implemented behavior:
- Added `channels.variant_key` through migration 4.
- Replaced channel uniqueness with `(source_id, variant_key)` so same-name variants can coexist when their stream ids or URLs differ.
- `Sql.insertChannel()` now upserts by variant key and resolves `lastChannelId` from the upserted row for header persistence.
- `Sql.getChannelsPreserve()` and `Sql.restorePreserve()` now preserve favorites/history by variant key.
- `Sql.getChannelVariants()` returns same-name, same-source, same-media rows for variant selection.
- Live rows, series episodes, and movie detail playback call `chooseChannelVariant()` before opening `Player`.
- `Choose version` appears only when more than one equivalent row exists.

Out of scope:
- General source-management redesign.
- EPG.

Verification:
- Import a source with duplicate variants if available.
- Select, remember, and reopen choice.
- Confirm no favorite/history loss.

Verification completed:
- `flutter test` passed with 39 tests.
- `flutter analyze --no-fatal-infos` exited 0. Existing info-level lints remain outside this phase.
- `flutter build apk --release` succeeded.
- `adb install -r build/app/outputs/flutter-apk/app-release.apk` succeeded.
- ADB smoke test confirmed the app starts after migration 4, Live `All channels` still opens playback, and Back returns to browsing.
- Release APK SHA256: `6D303E464FF37EBD4B06DEFEDB6253E8D2DD44F97D0BEDBF1D24BFFFE13849CE`.

Stop point:
- Approve before EPG data/UI work.

## Phase 10: EPG Data and UI V1

Goal:
- Add a real EPG pipeline and the first useful EPG view.

Status:
- Completed in this thread.

Expected files:
- Created `lib/models/epg_program.dart`
- Created `lib/backend/epg_service.dart`
- Created `lib/live_epg.dart`
- Modified `lib/backend/db_factory.dart`
- Modified `lib/backend/sql.dart`
- Modified `lib/backend/xtream.dart`
- Modified `lib/home.dart`
- Modified `lib/live_browse.dart`
- Modified `lib/models/view_type.dart`
- Added `test/epg_sql_test.dart`
- Added `test/epg_xtream_test.dart`
- Added `test/epg_service_test.dart`
- Added `test/live_epg_test.dart`
- Updated `test/live_browse_test.dart`

Scope:
- Add `ViewType.epg` and a Live-only `EPG` chip.
- Fetch Xtream `get_short_epg` lazily for loaded live rows.
- Persist short EPG rows in SQLite.
- Cache EPG results with a 6-hour TTL and bounded concurrency.
- Render Live now/next rows with missing-data states.
- Keep Browse/All/Favorites/History and player internals unchanged.

Implemented behavior:
- Migration 5 adds `epg_programs`.
- `EpgProgram` and `EpgNowNext` model the cached short EPG window.
- `Sql.replaceEpgPrograms()` replaces rows per channel and records empty no-data fetches to avoid repeated provider requests.
- `Sql.getNowNextEpgForChannels()` returns current and next programs for loaded channels.
- `Sql.isEpgCacheFresh()` enforces the default 6-hour TTL.
- Source wipe/delete clears EPG rows.
- `getShortEpgPrograms()` calls Xtream `get_short_epg` by live `stream_id`.
- EPG title/description decoding accepts Base64 or plain text.
- M3U sources return no EPG cleanly.
- `refreshEpgForChannels()` fetches with bounded concurrency of 3.
- `LiveEpgList` and `LiveEpgRow` render logo/name, current program, time range, next program, loading, and no-data states.
- Row tap uses the existing live playback path, including source variant selection and history.

Out of scope:
- Full grid EPG until list/columns EPG is stable.
- Player-side EPG overlay.

Verification:
- Fetch EPG for selected channels.
- Validate timezone/time display.
- Scroll EPG smoothly.
- Test missing EPG categories.

Verification completed:
- `flutter test` passed with 54 tests.
- `flutter analyze --no-fatal-infos` exited 0. Existing info-level lints remain.
- `flutter build apk --release` succeeded.
- `adb install -r build/app/outputs/flutter-apk/app-release.apk` succeeded.
- ADB smoke test confirmed Live shows the EPG chip, EPG mode renders rows with `No EPG data` where provider data is absent, tapping a row opens the player, and Back returns to the EPG list.
- Release APK SHA256: `6AF419FD993341A21DFF81121D86D1FAF6CD27124091A3D53AEF775AC2EE0EB4`.

Stop point:
- Approve before grid EPG.

## Phase 11: Metadata Expansion

Goal:
- Import and persist richer VOD/Series metadata needed for premium detail pages.

Status:
- Completed in this thread.

Expected files:
- Created `lib/models/media_metadata.dart`
- Created `lib/backend/metadata_service.dart`
- Created `lib/media_metadata_view.dart`
- Modified `lib/backend/db_factory.dart`
- Modified `lib/backend/sql.dart`
- Modified `lib/backend/xtream.dart`
- Modified `lib/movie_detail.dart`
- Modified `lib/series_detail.dart`
- Added `test/metadata_sql_test.dart`
- Added `test/metadata_xtream_test.dart`
- Added `test/metadata_service_test.dart`
- Updated movie and series detail widget tests

Scope:
- VOD info: overview, year, rating, duration, genre, backdrop if available.
- Series info: overview, year, rating, genre, cast, backdrop if available.
- Add metadata without breaking existing rows.

Implemented behavior:
- Migration 6 adds `media_metadata`.
- `MediaMetadata` stores synopsis, year, rating, duration, genres, cast, poster, backdrop, and fetched timestamp.
- Metadata is loaded lazily on movie/series detail pages through `loadMediaMetadata()`.
- Cache TTL defaults to 7 days.
- Movies use Xtream `get_vod_info` by `streamId`.
- Series use Xtream `get_series_info.info` by series id.
- M3U sources return no metadata cleanly.
- Parser handles common Xtream field variants and malformed optional fields.
- Movie and Series detail pages render metadata only when available.
- Play/Resume/Favorite/source-variant behavior is unchanged.

Out of scope:
- Player changes.
- EPG.
- Episode-specific rich metadata UI.
- External metadata APIs.

Verification:
- Refresh source.
- Confirm old rows survive migration.
- Confirm detail pages show metadata when available and degrade cleanly.

Verification completed:
- `flutter test` passed with 65 tests.
- `flutter analyze --no-fatal-infos` exited 0. Existing info-level lints remain.
- `flutter build apk --release` succeeded.
- `adb install -r build/app/outputs/flutter-apk/app-release.apk` succeeded.
- ADB smoke confirmed Movie detail opens after migration 6, provider metadata can render on detail, Series detail renders year/rating/synopsis plus episodes, and tapping an episode still opens the player.
- Release APK SHA256: `D7B31317835F4135D099271C4D5B69623410525906566EDB894655C689848B23`.

Stop point:
- Approve before visual polish pass.

## Phase 12: Performance and Polish Pass

Goal:
- Measure and tighten the app after the major UX surfaces exist.

Status:
- Completed in this thread.

Expected files:
- Created `lib/load_request_guard.dart`
- Created `lib/channel_widget_key.dart`
- Modified `lib/home.dart`
- Modified `lib/live_browse.dart`
- Modified `lib/live_epg.dart`
- Modified `lib/movie_detail.dart`
- Added `test/load_request_guard_test.dart`
- Added `test/channel_widget_key_test.dart`
- Added `test/browse_loading_footer_test.dart`
- Updated movie and EPG widget tests
- Updated docs after completion

Scope:
- Profile scroll and frame timing.
- Reduce unnecessary rebuilds.
- Audit image dimensions/cache.
- Add stable keys where needed.
- Tighten transitions, skeletons, and empty states.

Implemented behavior:
- ADB audit captured Live Browse, Live All, Live EPG, Movies All, and Series All under `docs/research/phase12_audit/`.
- Channel tiles and Live EPG rows now use stable widget keys from channel id or variant key.
- Home search/pagination now uses `LoadRequestGuard` so stale debounced results cannot replace a newer result set.
- Load-more requests are locked while one is in flight.
- A compact `BrowseLoadingFooter` appears while additional rows are loading.
- Wide movie detail now keeps Play/Resume actions before provider metadata, matching the mobile behavior and reducing metadata-load layout disruption.

Out of scope:
- New major features.
- Database migrations.
- Player redesign.
- EPG grid or overlay.

Verification:
- ADB smoke test.
- Flutter performance overlay/profile run where feasible.
- Large list scroll checks.

Verification completed:
- `flutter test` passed with 71 tests.
- `flutter analyze --no-fatal-infos` exited 0. Existing info-level lints remain outside this phase.
- `flutter build apk --release` succeeded and produced `build/app/outputs/flutter-apk/app-release.apk` at 97.3 MB.
- `adb install -r build/app/outputs/flutter-apk/app-release.apk` succeeded.
- ADB smoke confirmed Topal package focus before captures and verified Live Browse, Live All scroll, Live EPG rows, Movies All, Movie detail Play action, Series All, Series detail metadata/episodes, episode playback route, and Back returning to Series detail.
- Final smoke artifacts are stored under `docs/research/phase12_final_smoke/`.
- Release APK SHA256: `BDB4C1813DBFBB04B3C758CCABE1263B20628201E26B84676A9A0A86C9482F05`.

Stop point:
- Approve before release hardening.

## Phase 13: Release Hardening

Goal:
- Prepare the app for reliable APK testing and broader use.

Status:
- Completed in this thread.

Expected files:
- Modified `android/settings.gradle`
- Modified `android/gradle/wrapper/gradle-wrapper.properties`
- Modified `android/app/build.gradle`
- Updated documentation

Scope:
- Gate Android build-tool upgrades one at a time.
- Resolve safe Gradle/Kotlin/NDK build warnings.
- Preserve APK build/install reliability.
- Keep broader Built-in Kotlin migration out of this phase.

Implemented behavior:
- Baseline verification passed before Android config edits.
- Kotlin Gradle Plugin upgraded from `2.1.0` to `2.2.21`; release build succeeded and Flutter's Kotlin-version warning disappeared.
- Gradle wrapper upgraded from `8.13` to `8.14.3`; release build succeeded and Flutter's Gradle-version warning disappeared.
- Android NDK pinned to `28.2.13676358`; release build succeeded and the NDK mismatch warning disappeared.
- A transient R8 delete failure was traced to stale Gradle/Kotlin daemons holding `classes.dex`; stopping those daemons and rerunning the same build succeeded, so it was not treated as a Gradle compatibility failure.

Out of scope:
- New UX features.
- Built-in Kotlin migration.
- App signing-key changes.
- Dependency major-version upgrades.

Verification:
- Release APK build.
- Install on device.
- Smoke-test setup, browsing, playback, settings.

Verification completed:
- Baseline `flutter test` passed with 71 tests.
- Baseline `flutter analyze --no-fatal-infos` exited 0 with the same existing 13 info-level lints.
- Baseline `flutter build apk --release` succeeded and reproduced the Gradle/Kotlin/NDK warnings.
- Kotlin gate: `flutter test`, `flutter analyze --no-fatal-infos`, and release build all succeeded.
- Gradle gate: `flutter test`, `flutter analyze --no-fatal-infos`, and release build all succeeded after clearing stale build daemons.
- NDK gate: `flutter test`, `flutter analyze --no-fatal-infos`, and release build all succeeded.
- Final `adb install -r build/app/outputs/flutter-apk/app-release.apk` succeeded.
- Final ADB smoke confirmed app start, Live All scroll, Live EPG rows, Movie detail, Series detail, episode playback route, and Back returning to Series detail.
- Final APK SHA256: `F5796C3055D09391480C010300BE1B7BFA2783599BDC09C9A6F40DBEFDCBF30F`.
- Final ADB smoke artifacts are recorded in `docs/research/phase13_release_hardening.md` and `docs/research/phase13_final_smoke/`.

Stop point:
- Produce APK and final QA notes.

## Phase 14: Built-in Kotlin Migration / Signing Hardening

Goal:
- Add safe release signing configuration and test whether Built-in Kotlin migration is compatible with the current Flutter/Android toolchain.

Status:
- Completed in this thread.

Scope:
- Migrate Android Gradle setup to Built-in Kotlin only if plugin compatibility is clear.
- Replace debug release signing with a real release signing configuration if distribution requires it.
- Keep UX and database behavior unchanged.

Implemented behavior:
- Added release signing config in `android/app/build.gradle` that reads `android/key.properties` only when present.
- Added `android/key.properties.example` with placeholder values only.
- Preserved debug signing fallback when `android/key.properties` is absent, so local APK testing remains unchanged.
- Tested Built-in Kotlin with AGP `9.0.1`, Gradle `9.1.0`, `android.builtInKotlin=true`, and `android.newDsl=true`.
- Rolled back Built-in Kotlin/AGP9/Gradle9 because Flutter 3.44.1's `dev.flutter.flutter-gradle-plugin` failed under AGP 9 new DSL.
- Kept Phase 13's stable toolchain: AGP `8.13.2`, Gradle `8.14.3`, Kotlin Gradle Plugin `2.2.21`, NDK `28.2.13676358`.

Verification completed:
- Baseline `flutter test`, `flutter analyze --no-fatal-infos`, and `flutter build apk --release` succeeded before Phase 14 edits.
- Signing gate `flutter test`, `flutter analyze --no-fatal-infos`, and `flutter build apk --release` succeeded without `android/key.properties`.
- `flutter build appbundle --release` failed because the local Android toolchain has broken/missing strip tooling; NDK 28 `llvm-strip.exe` is 0 bytes and Flutter doctor reports missing cmdline-tools.
- Built-in Kotlin gate `flutter test` and analyze succeeded, but APK build failed at Flutter Gradle plugin application with AGP 9 new DSL; rollback was applied.
- Post-rollback `flutter test`, `flutter analyze --no-fatal-infos`, and final `flutter build apk --release` succeeded.
- Final `adb install -r build/app/outputs/flutter-apk/app-release.apk` succeeded.
- Final ADB smoke confirmed app start, Live All scroll, Live EPG, Movie detail, Series detail, episode playback, and Back returning to Series detail.
- After the final APK reinstall, ADB start confirmed Topal focused and rendered the Live root screen.
- Final APK SHA256: `F49F3EFC45E24D6101917D6649D14C52F19C832EE037B471C29254E6BF0C9CFD`.
- Final ADB smoke artifacts are stored under `docs/research/phase14_final_smoke/`.

Stop point:
- Produce APK and final QA notes.

## Phase 15: Android Toolchain Repair / AAB Packaging

## Phase 16: Kotlin Warning Cleanup

Goal:
- Remove Topal's own unnecessary Kotlin Gradle Plugin usage and reduce plugin-side warning surface with stable dependency upgrades.

Status:
- Completed in this thread.

Implemented behavior:
- Converted Android host `MainActivity` from Kotlin to Java.
- Removed `kotlin-android` and `kotlinOptions` from the app module.
- Upgraded stable `file_picker` to `11.0.2`.
- Updated file picker usage to the v11 static API.
- Kept `device_info_plus` and `package_info_plus` on the current resolving stable line because their newer versions conflict with stable `file_picker` through incompatible `win32` constraints.

Verification completed:
- `flutter pub get` succeeded.
- `flutter test` passed with 71 tests.
- `flutter analyze --no-fatal-infos` exited 0 with the existing 13 info-level lints.
- `flutter build apk --release` succeeded.
- `flutter build appbundle --release` succeeded.
- `adb install -r build/app/outputs/flutter-apk/app-release.apk` succeeded.
- ADB launch smoke confirmed Topal focused and rendered the Live root screen.
- APK SHA256: `C4388F284E960D72E6FA7541023AB9BDEEABECE8A6FEC5188D40CB3C6CC466F7`.
- AAB SHA256: `CA398596CF1F4880BC9BC0FDC7D49B327A3BA5CCDCEC8D0ABD6AE49ABC406BA5`.

Remaining warning:
- Flutter no longer warns that the app module applies KGP.
- Flutter still warns that upstream plugins apply KGP: `device_info_plus`, `file_picker`, `package_info_plus`, and `wakelock_plus`.
- This is deferred until stable plugin releases support Built-in Kotlin without conflicting dependency constraints.

## Approval Request

The recommended next executable phase is Phase 17: Plugin Built-in Kotlin Readiness.

Do not start Phase 17 until the user explicitly approves it.
