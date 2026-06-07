# Topal IPTV Architecture State

Date: 2026-06-07

## Purpose

This document maps the current Topal IPTV Flutter/Dart codebase before major UX work begins. It is intended to preserve existing behavior while the app is upgraded incrementally.

## High-Level Shape

Topal IPTV is a Flutter application with:
- A mobile-first home screen in `lib/home.dart`
- A separate TV launcher in `lib/tv_home.dart`
- Live browsing helpers in `lib/live_browse.dart`
- Live EPG helpers in `lib/live_epg.dart` and `lib/backend/epg_service.dart`
- Metadata helpers in `lib/media_metadata_view.dart` and `lib/backend/metadata_service.dart`
- A VOD detail route in `lib/movie_detail.dart`
- A series detail route in `lib/series_detail.dart`
- A shared playback screen in `lib/player.dart`
- Player control configuration helpers in `lib/player_controls/`
- SQLite persistence through `sqlite_async`
- IPTV imports from Xtream and M3U sources
- Material 3 dark theme
- `media_kit` for playback

The current app is functional and compact. Most behavior is implemented directly in widgets and static backend helper classes rather than in a formal state-management framework.

## Startup Flow

Entry point: `lib/main.dart`

Startup steps:
1. `WidgetsFlutterBinding.ensureInitialized()`
2. `MediaKit.ensureInitialized()`
3. Load persisted sources through `Sql.hasSources()`
4. Load settings through `SettingsService.getSettings()`
5. Detect touch support through `Utils.hasTouchScreen()`
6. Detect TV device through `DeviceDetector.isTV()`
7. Render one of:
   - `Setup` if no source exists
   - `TvHome` if TV mode is forced, Android/Apple TV is detected, or no touch screen exists
   - `Home` for normal mobile mode

Important startup behavior:
- Optional refresh-on-start can block initial content while `Utils.refreshAllSources()` runs.
- `WhatsNewModal` is triggered on first launch of a version through `SettingsService.shouldShowWhatsNew()`.
- Global keyboard shortcuts map Escape and Backspace to `Navigator.maybePop()` when text editing is not active.

## App Shells

### Mobile Shell

Primary files:
- `lib/home.dart`
- `lib/mobile_shell_nav.dart`
- `lib/live_browse.dart`
- `lib/models/mobile_section.dart`
- `lib/models/browse_layout.dart`

Current responsibilities:
- Owns `HomeManager`, `Filters`, search query state, pagination state, and current channel list.
- Loads settings, enabled sources, and initial data in `initAsync()`.
- Uses `LoadRequestGuard` to prevent stale debounced search results and overlapping pagination results from mutating current list state.
- Uses `CustomScrollView` with:
  - `SliverAppBar` containing search input and optional nested node title
  - `SliverGrid` for channel/category cards
  - Loading indicators and a compact pagination footer
- Uses fixed `pageSize = 36`.
- Adds more rows when scroll position passes 75 percent of max scroll extent.
- Shows a floating scroll-to-top button after 200 px.
- Uses `MobileShellNav` for media-first mobile destinations: Live, Movies, Series, Settings.
- Keeps Browse, All, Favorites, and History as secondary chips under search.
- Adds a Live-only EPG secondary chip.
- Uses `BrowseLayout` as a thin presentation decision layer for category rows, live rows, mixed rows, and poster grids.
- Uses `LiveBrowseHeader` on root Live screens as a small context/action layer.
- Uses `LiveEpgList` when Live EPG mode is selected.

Current navigation model:
- Bottom nav changes the active `MobileSection`, which maps to one `MediaType`.
- Switching Live, Movies, or Series starts at `ViewType.categories` with a single media type filter.
- Secondary chips change the root `ViewType` while preserving the active media section.
- Live EPG is represented by `ViewType.epg` and is available only when the active section is Live and global search is off.
- Searching while the Browse chip is selected searches media items, not category names.
- The `All media` secondary chip searches across enabled Live, Movies, and Series media types and marks each result with its type.
- `Browse` shows categories for the active section when there is no search query.
- `All` shows all items inside the active section without category grouping.
- `All media` is global only for enabled media types and remains visually distinct with result labels.
- Root Live screens can show direct context actions such as All channels or Categories.
- Category navigation pushes a new `Home` with a `Node`.
- Top-level series navigation pushes `SeriesDetailPage`.
- Movie navigation pushes `MovieDetailPage` first when the item is a top-level movie.
- Live and series episode navigation still push `Player` directly.
- Live EPG rows also push `Player` through the same source-variant picker/history/settings path.
- Repeated channel widgets and EPG rows use stable keys from database ids or source variant identity to reduce unnecessary element churn during large-list updates.

### TV Shell

Primary file: `lib/tv_home.dart`

Current responsibilities:
- Provides a tile-based launcher with large focusable `MenuTile` entries.
- First level includes Channels, Categories, Favorites, History, Settings.
- Selecting non-settings entries moves to a media-type selection screen.
- Media type selection starts `Home(hasTouchScreen: false)` with filtered `MediaType` values.

Current strengths:
- Separate TV mode already exists.
- Focus styling and keyboard/remote traversal are considered.

Current limitation:
- TV and mobile shells now both expose media modes, but TV still uses its original two-step launcher while mobile uses a persistent bottom shell.

## Routing and State

Routing is imperative and local:
- `Navigator.push()`
- `Navigator.pushAndRemoveUntil()`
- `MaterialPageRoute`
- `NoPushAnimationMaterialPageRoute`
- `PageRouteBuilder` for zero-duration transitions in settings navigation

State is mostly local widget state:
- `Home` keeps list, filters, loading flags, search controller, and scroll controller.
- `Home` also keeps the selected `MobileSection` for the mobile shell.
- `ChannelTile` keeps local favorite and focus state.
- `SettingsView` keeps settings and source list.
- `Setup` keeps stepper state and form values.
- `Player` owns media_kit player/controller lifecycle.

Global memory:
- `lib/memory.dart` stores `refreshedSeries`, used to avoid repeatedly fetching series episodes during one runtime session.

State-management implication:
- A future state-management choice should be introduced only after the shell boundaries are clearer.
- For early phases, preserve the existing simple local-state approach and extract focused widgets/services only when needed.

## Playback

Primary file: `lib/player.dart`

Supporting files:
- `lib/player_controls/player_control_profile.dart`
- `lib/player_controls/material_player_controls.dart`
- `lib/player_controls/vod_transport.dart`
- `lib/player_controls/live_channel_context.dart`
- `lib/channel_variant_picker.dart`

Current behavior:
- Creates a `media_kit` `Player` and `VideoController`.
- Opens a `Media` item from the selected `Channel`.
- Enters fullscreen after opening playback.
- For movies, restores saved position from `Sql.getPosition()`.
- On exit/dispose, saves movie position through `Sql.setPosition()`.
- For live streams, retries playback when the stream completes.
- If low latency is enabled, sets mpv cache-related properties for livestream playback.
- Loads optional per-channel HTTP headers from SQLite and sends them to media_kit.
- Playback entry points ask `channel_variant_picker.dart` for an alternate channel row before opening `Player` when duplicate variants exist.

Current control model:
- Uses `MaterialVideoControlsThemeData`.
- Top button bar: back button and channel title.
- Bottom button bar: subtitle, audio track, aspect ratio controls.
- Live stream disables seek bar and seek gestures.
- `PlayerControlProfile` maps media type to Live or VOD behavior.
- `material_player_controls.dart` builds the current Material controls from a profile and callbacks.
- VOD controls include 10-second skip backward, restart, and 10-second skip forward.
- Live controls intentionally omit VOD transport buttons and instead show previous/next channel controls when a loaded live context is available.
- Live controls show a `LIVE x / y` badge when opened from a loaded live list.

Current lifecycle boundary:
- `Player` owns playback lifecycle, HTTP headers, fullscreen entry/exit, low-latency mpv setup, reconnect, and position persistence.
- `PlayerControlProfile` owns seek/resume/reconnect policy.
- `material_player_controls.dart` owns current Material controls composition.
- `vod_transport.dart` owns VOD seek target clamping for skip buttons.
- `LiveChannelContext` owns loaded live channel navigation state passed from `Home` through `ChannelTile` into `Player`.
- `channel_variant_picker.dart` owns the modal variant chooser; `Player` still receives a single selected `Channel`.

Current limitations:
- Live and VOD are now separated by control profile, but both still render the same basic Material controls layout.
- No custom live channel drawer.
- No sleep timer.
- No volume rail.
- Source/version picker exists for same-name channel variants, but the main browsing lists are not deduplicated yet.
- VOD controls lack rich title/synopsis/restart/skip UX compared with Zen Player.

## VOD Detail Route

Primary file: `lib/movie_detail.dart`

Current behavior:
- `ChannelTile` routes top-level `MediaType.movie` rows to `MovieDetailPage`.
- Series episodes currently remain direct-to-player because they are also stored as `MediaType.movie` but have `seriesId`.
- `MovieDetailPage` reads saved movie position from `Sql.getPosition()`.
- The page resolves source variants through `chooseChannelVariant()` before opening `Player`.
- History continues to be written through `Sql.addToHistory()`.
- Favorite state uses the existing `favorite` column and `Sql.favoriteChannel()`.
- `Start over` resets the saved position to 0 through `Sql.setPosition()` before playback.
- `MovieDetailPage` loads provider metadata lazily through `loadMediaMetadata()`.
- `MovieDetailBody` renders metadata through shared `MetadataDetails` and `MetadataBackdrop` widgets when cache/provider data exists.

Architectural implication:
- The VOD decision point now supports same-name source variants without changing player lifecycle.
- Metadata is now behind this route without changing the Movies grid tap behavior.

## Series Detail Route

Primary file: `lib/series_detail.dart`

Current behavior:
- `ChannelTile` routes top-level `MediaType.serie` rows to `SeriesDetailPage`.
- `SeriesDetailPage` resolves the series identifier from the series row URL and uses it as the episode `seriesId`.
- If the series has not been refreshed in the current runtime, the page calls the existing `getEpisodes()` flow and stores the series row id in `refreshedSeries`.
- Episodes are then read from SQLite with `Sql.search()` using `ViewType.all`, `MediaType.movie`, the active source id, and the selected `seriesId`.
- Episodes are grouped by inferred season labels from episode names; unknown formats fall back to a single `Episodes` section.
- The page loads top-level series metadata lazily through `loadMediaMetadata()`.
- Tapping an episode resolves source variants, then opens the existing `Player` after loading settings and writing history.

Architectural implication:
- Series now has a user-facing detail route without changing the import pipeline, database schema, or player lifecycle.
- Series metadata enriches the route while preserving the current episode storage model of `MediaType.movie` plus `seriesId`.

## Metadata Pipeline

Primary files:
- `lib/backend/metadata_service.dart`
- `lib/backend/xtream.dart`
- `lib/backend/sql.dart`
- `lib/models/media_metadata.dart`
- `lib/media_metadata_view.dart`

Current behavior:
- Migration 6 adds `media_metadata`.
- Movie details fetch Xtream `get_vod_info` lazily by movie `streamId`.
- Series details fetch Xtream `get_series_info.info` lazily by series id.
- Cache TTL defaults to 7 days.
- M3U sources skip provider metadata and keep the existing simple UI.
- Parser helpers tolerate common Xtream field-name variants and malformed optional values.
- Detail pages render synopsis, year, rating, duration where applicable, genres, cast, poster fallback, and backdrop without changing playback.

Architectural implication:
- Metadata is optional detail-page state, not a full import-time dependency.
- The player, EPG, search, source variants, and list layouts are not coupled to metadata.

## Live EPG Pipeline

Primary files:
- `lib/backend/epg_service.dart`
- `lib/backend/xtream.dart`
- `lib/backend/sql.dart`
- `lib/models/epg_program.dart`
- `lib/live_epg.dart`

Current behavior:
- `ViewType.epg` adds a Live-only mode in the mobile shell.
- `Home` fetches EPG lazily for currently loaded live channels after the normal paged channel query.
- `refreshEpgForChannels()` skips non-live rows, channels without ids, channels without stream ids, and channels with fresh cache.
- Xtream sources use `get_short_epg` by live stream id.
- M3U sources currently resolve to no EPG without provider requests.
- Fetches are bounded to 3 concurrent channels.
- SQLite stores short EPG rows in `epg_programs` and records no-data fetches with an empty marker row.
- The UI renders now/next rows with local time ranges and no-data/loading states.

Architectural implication:
- EPG is now isolated as a small service and Sliver UI layer.
- Full grid EPG and player overlay can build on the same cache/query helpers without changing import or player lifecycle in this phase.

## Settings

Primary files:
- `lib/settings_view.dart`
- `lib/backend/settings_service.dart`
- `lib/models/settings.dart`

Settings currently include:
- Default view
- Refresh sources on start
- Show livestreams
- Show movies
- Show series
- Force TV mode
- Low latency livestreams
- Last seen app version for "What's new"

Settings are persisted as key/value strings in the `settings` SQLite table.

## Setup and Source Management

Primary files:
- `lib/setup.dart`
- `lib/edit_dialog.dart`
- `lib/settings_view.dart`

Supported source types:
- Xtream
- M3U URL
- M3U local file

Setup flow:
- Welcome
- Source type
- Source name
- URL
- Username
- Password
- Finish

For Xtream URLs without a path, setup can suggest appending `player_api.php`.

## Build and Runtime Dependencies

Important dependencies from `pubspec.yaml`:
- `media_kit`, `media_kit_video`, `media_kit_libs_video`
- `sqlite_async`, `sqlite3_flutter_libs`
- `cached_network_image`
- `http`
- `path_provider`
- `device_info_plus`
- `package_info_plus`
- `flutter_form_builder`, `form_builder_validators`
- `loader_overlay`
- `flutter_spinkit`
- `animations`
- `file_picker`

The release APK previously built successfully at:
- `build/app/outputs/flutter-apk/app-release.apk`

Build note:
- `android/gradle.properties` includes `kotlin.incremental=false` to avoid a Kotlin incremental-cache issue in this environment.
- Phase 13 release hardening verified Android build tooling with Flutter 3.44.1, AGP 8.13.2, Gradle wrapper 8.14.3, Kotlin Gradle Plugin 2.2.21, and Android NDK 28.2.13676358.
- The Gradle/Kotlin/NDK version warnings from Phase 12 builds are resolved. The remaining Android build warning is Flutter's future Built-in Kotlin migration warning for app/plugin Gradle setup.
- Phase 14 adds release signing configuration that reads `android/key.properties` when present and falls back to debug signing when absent, preserving local APK testing.
- Built-in Kotlin with AGP 9.0.1 / Gradle 9.1.0 was tested and rolled back because Flutter 3.44.1's Gradle plugin failed under AGP 9 new DSL.
- `flutter build appbundle --release` is currently blocked by the local Android SDK/NDK install: `llvm-strip.exe` under NDK 28.2.13676358 is 0 bytes and Flutter doctor reports missing Android cmdline-tools.

## Behavior to Preserve

During incremental work, preserve:
- Existing source setup and import flows
- Existing search behavior
- Existing favorites toggling
- Existing history trimming to 36 items
- Existing movie resume position
- Existing TV mode entry and focusability
- Existing settings persistence
- Existing low-latency livestream setting
- Existing HTTP header support for M3U streams
- Existing lazy series episode fetch
- Existing no-source setup path
- Phase 1 media-first mobile shell behavior: Live, Movies, Series, Settings primary navigation with Browse, All, Favorites, History as secondary filters.
- Search behavior after Phase 1 fix: section search returns media items within that section; `All media` returns mixed enabled media types with result labels.
- Phase 2 media-aware browsing behavior: Browse remains category-first; All is flat within the active section; Movies and Series use poster cards; Live uses dense rows.
- Phase 3 VOD detail behavior: top-level movies open `MovieDetailPage`; Live and existing series episodes still open `Player` directly.
- Phase 4 Series detail behavior: top-level series open `SeriesDetailPage`; episodes are grouped by season and still open `Player` directly.
- Phase 5 Live browsing behavior: root Live screens show `LiveBrowseHeader`; empty Live Favorites can route back to Browse; dense rows and playback remain unchanged.
- Phase 6 Player split behavior: `Player` uses `PlayerControlProfile` and `material_player_controls.dart` so Live and VOD control configuration can diverge without changing playback lifecycle.
- Phase 7 VOD player controls behavior: VOD/episode controls show back 10, restart, and forward 10; Live controls remain unchanged.
- Phase 8 Live player controls behavior: Live controls show `LIVE x / y` and previous/next channel buttons when opened from a loaded live list; VOD controls remain unchanged.
- Phase 9 Source variant behavior: `channels.variant_key` allows same-name stream variants, refresh preserve uses variant keys, and Live/Movie/Episode playback shows a variant picker only when more than one equivalent row exists.
- Phase 10 EPG V1 behavior: Live-only EPG mode fetches/caches short Xtream now/next data lazily, M3U shows no-data, and row taps preserve the existing playback/variant path.
- Phase 11 Metadata behavior: Movie/Series detail pages lazily cache Xtream metadata and render it only when available, while M3U/detail fallbacks and playback remain unchanged.
- Phase 12 Performance/Polish behavior: Home search and pagination ignore stale results, load-more requests do not overlap, repeated media rows keep stable keys, and movie detail keeps playback actions above metadata in wide layouts.
- Phase 13 Release Hardening behavior: Android build tool upgrades are gated by tests/analyze/release builds, and the final APK remains installable over the existing app with database migrations intact.
- Phase 14 Signing behavior: release builds use a real signing config only when `android/key.properties` exists; otherwise release APKs continue to build with debug signing for local testing.

## Architectural Risks

1. Mobile navigation is currently view-type based, not media-mode based. Adding Live/Movies/Series should be done as a thin shell layer before data refactors.
2. `Channel` is overloaded for channels, movies, series, episodes, and groups. It is simple but can become confusing as UI becomes richer.
3. Rich VOD/Series metadata is persisted lazily per opened detail page, so browsing-card metadata remains a separate future concern.
4. EPG V1 is short-window and provider-lazy only; full XMLTV/grid/player overlay work remains a later risk area.
5. The player currently owns retry, fullscreen, position saving, and controls together. Custom controls should be added carefully around this lifecycle.
6. Source variant grouping is currently exact-name based; quality suffix normalization and list deduplication are not implemented yet.
7. There is no current repository metadata in this workspace (`git status` reported no `.git` directory), so change tracking must be done through files and explicit verification until a repo is available.
8. Flutter still warns that the app/plugins use Kotlin Gradle Plugin instead of Built-in Kotlin. Phase 14 proved the AGP 9 / Built-in Kotlin migration is not compatible with the current Flutter Gradle plugin.
9. AAB release packaging is blocked by the local Android SDK toolchain until cmdline-tools and a valid NDK `llvm-strip.exe` are repaired.
