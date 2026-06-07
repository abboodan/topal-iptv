# Topal IPTV UI Components State

Date: 2026-06-07

## Purpose

This document maps current UI components and interaction behavior before professional UX work begins.

## Theme and App Wrapper

Primary file: `lib/main.dart`

Current theme:
- Dark Material 3
- Seed color: blue
- Scaffold background: black
- Card color uses `surfaceContainer`
- Focused filled buttons receive a yellow border when touch is not available

Global app behavior:
- `Shortcuts` and `Actions` wire Escape/Backspace to back navigation outside text fields.
- `LoaderOverlay` is available around main screens through `Loading`.

Design implication:
- The app already has a dark foundation. The upgrade should refine this into a media-oriented visual system rather than replace it with a light or generic theme.

## Mobile Home

Primary files:
- `lib/home.dart`
- `lib/mobile_shell_nav.dart`
- `lib/live_browse.dart`
- `lib/models/mobile_section.dart`
- `lib/models/browse_layout.dart`

Current UI:
- `Scaffold`
- `SafeArea`
- `CustomScrollView`
- Search field inside `SliverAppBar`
- Secondary filter chips: Browse, All, All media, EPG on Live only, Favorites, History
- Live-specific contextual header on the root Live section
- Optional nested title when inside category or series
- `SliverGrid` of `ChannelTile`
- Compact pagination footer while loading additional rows
- Bottom navigation through `MobileShellNav`
- Floating scroll-to-top button

Current layout behavior:
- Grid layout is now selected by `BrowseLayout.forState()`.
- `Browse` without a query uses category rows.
- Live item views use dense rows.
- Live EPG mode uses a `SliverList` of now/next rows.
- Movies and Series item views use poster cards.
- `All media` uses mixed rows with media type labels.
- Cross-axis count and fixed item extent vary by layout:
  - Poster cards target about 150 px per column and clamp between 2 and 6 columns.
  - Live rows target about 360 px per column and clamp between 1 and 2 columns.
  - Category and mixed rows target about 350 px per column and clamp between 1 and 3 columns.

Interaction behavior:
- Search is debounced by 500 ms.
- Infinite loading triggers near 75 percent scroll progress.
- Pagination requests are guarded so overlapping load-more requests cannot update the list out of order.
- Search/list reload requests are sequenced so stale SQL results do not replace newer query results after debounce.
- Nested category/series navigation creates another `Home` route with an updated `Node`.
- Bottom nav switches Live, Movies, and Series by setting a single media type filter.
- Settings remains a primary bottom destination.
- Favorites and History remain available through secondary chips instead of primary bottom destinations.
- Search entered on Browse now returns matching media items within the active section rather than matching only category names.
- `All media` is a secondary chip for cross-type search. Results show a small type label such as Live, Movie, or Series.
- Root Live screens show a context header with a direct action between categories and all channels.
- Root Live screens show an `EPG` chip. It stays hidden in Movies, Series, and global `All media` search.
- Live EPG rows lazily fetch short Xtream EPG for loaded rows and keep row taps on the existing playback path, including source variant selection.

Strengths:
- Uses slivers and builder-based grids, which is a good base for large IPTV datasets.
- Pagination keeps memory pressure low.
- Media-specific layout selection is isolated from the SQL/data layer.
- Live browsing now has a clearer first-viewport state before player overlay work begins.
- Repeated channel/list rows now use stable keys based on database id or source variant identity.

Limitations:
- Media-specific surfaces are still first-pass browsing layouts, not full detail or discovery pages.
- No curated discovery rails exist yet.
- Poster cards still rely only on existing `Channel.image` and `Channel.name`; richer discovery cards remain a later metadata/polish phase.

## ChannelTile

Primary file: `lib/channel_tile.dart`

Current UI:
- `Card`
- `InkWell`
- Layout selected by `ChannelTileLayout`
- Category and mixed/live rows use a horizontal card with cached square image, name text, and optional media type label.
- Live rows use a denser fixed extent than generic rows.
- Poster layout uses a clipped card with a cover image, title text, and favorite action overlay for non-group items.
- Favorite star action remains available for non-group items.

Current interaction:
- Tap group: navigate into category.
- Tap series: open `SeriesDetailPage`, which lazily fetches episodes if not fetched in the current runtime.
- Tap movie without `seriesId`: open `MovieDetailPage`.
- Tap live/episode: open `Choose version` when duplicate variants exist, then add the selected row to history and open `Player`.
- Long press non-group: toggle favorite.
- Focus state changes card color for non-touch/TV flows.

Strengths:
- Single, predictable entry component.
- Uses `CachedNetworkImage` with memory cache dimensions of 300 x 300.
- Supports focus styling.
- Can now present Live, Movies, Series, categories, and global search differently without changing tap behavior.

Limitations:
- Long press favorite is hidden behavior.
- Series detail now owns episode loading and can show top-level provider metadata, but episode rows remain simple.
- VOD and Series detail routes are richer, but browsing cards still do not show synopsis/rating metadata.
- The wrapper still owns multiple media concepts; later phases should extract true `LiveChannelRow`, `PosterCard`, and `SeriesCard` widgets when their behavior diverges.

Future direction:
- Split presentation into media-specific cards:
  - `LiveChannelRow`
  - `CategoryChip` or `CategoryRow`
  - `PosterCard`
  - `SeriesCard`
  - `EpisodeRow`
- Keep `ChannelTile` as a compatibility wrapper until each flow migrates.

## Movie Detail

Primary file: `lib/movie_detail.dart`

Current UI:
- `MovieDetailPage`
- `MovieDetailBody`
- `MetadataDetails`
- `MetadataBackdrop`
- App bar with movie title
- Compact portrait layout with poster, title, category chips, favorite action, and Play/Resume button visible in the first viewport
- Wider layout places poster and metadata side by side
- Uses provider poster fallback when the channel image is absent.
- Shows provider synopsis, year, rating, duration, genres, cast, and backdrop when available.

Current interaction:
- Primary action opens the existing `Player`.
- If duplicate movie variants exist, the primary action opens `Choose version` before playback.
- If `Sql.getPosition()` returns a saved position, the button label changes to `Resume mm:ss` or `Resume h:mm:ss`.
- `Start over` appears only when a saved position exists and resets the saved movie position before playback.
- Favorite toggles through existing `Sql.favoriteChannel()`.
- Playback still uses existing history, settings, HTTP header, and resume handling.
- Metadata loads lazily from cache/provider after opening the page. Missing metadata does not block playback.

Strengths:
- Adds the first VOD decision point and supports same-name source variants before playback.
- Keeps the page testable through a pure `MovieDetailBody`.
- Preserves direct playback for series episodes until the dedicated Series detail phase.

Limitations:
- No external metadata enrichment; V1 uses only Xtream provider fields.
- Metadata loading has no visible skeleton in this phase.

Future direction:
- Phase 12 can polish metadata layout density, image treatment, and loading states.
- VOD player controls remain a separate later phase.

## Series Detail

Primary file: `lib/series_detail.dart`

Current UI:
- `SeriesDetailPage`
- `SeriesDetailBody`
- `MetadataDetails`
- `MetadataBackdrop`
- App bar with series title
- Header with poster, title, Series chip, and category chip
- Provider synopsis, year, rating, genres, cast, and backdrop when available
- Episode groups rendered as season sections
- Episode rows with thumbnail, title, and play affordance
- Loading, error, retry, and empty states

Current interaction:
- Opening a top-level series routes to `SeriesDetailPage`.
- The page refreshes episodes once per runtime using the existing `getEpisodes()` and `refreshedSeries` behavior.
- Episodes are read from SQLite as `MediaType.movie` rows linked by `seriesId`.
- Top-level series metadata loads lazily from cache/provider.
- Tapping an episode opens `Choose version` when duplicate episode variants exist, then opens the existing `Player`, preserving settings, history, HTTP headers, and player lifecycle.

Strengths:
- Replaces raw nested series navigation with a clearer show-detail decision point.
- Keeps episode loading and grouping testable through pure helpers and a separate body widget.
- Avoids player lifecycle changes in this phase.

Limitations:
- Season grouping is inferred from episode names and falls back to a single `Episodes` group when names do not expose season numbers.
- Episode rows still do not expose rich episode descriptions/durations.
- `get_series_info` can still be involved in both metadata and episode loading; future work can consolidate that path further.

Future direction:
- Later metadata phases can enrich episode rows and add episode detail if needed.
- Series episode player controls remain part of the later player-control phases.

## Live Browse

Primary file: `lib/live_browse.dart`

Current UI:
- `LiveBrowseHeader`
- `BrowseEmptyState`
- `BrowseLoadingFooter`
- Live-only `EPG` chip through `shouldShowLiveEpgChip()`
- Header icon, title, short description, and one direct action
- Live Favorites empty action: `Browse live channels`

Current interaction:
- Root Live `Browse` mode shows `Live TV` with an `All channels` action.
- Root Live `All` mode shows `All channels` with a `Categories` action.
- Root Live `EPG` mode shows `Live EPG` with an `All channels` action.
- Root Live Favorites and History show live-specific context text.
- Empty Live Favorites can route back to category browsing.
- Nested category screens do not show the header, preserving the category content focus.

Strengths:
- Adds Live-specific intent without changing SQL, import, or player behavior.
- Keeps the existing horizontal chip model and dense live row layout.
- The mode decisions are covered by small pure tests.

Limitations:
- This is still list-based; there is no full timeline grid or player-side EPG overlay.
- The header copy is generic because channel counts are not available in this phase.

Future direction:
- Later EPG phases can add a horizontal timeline grid and player overlay once the short EPG cache is stable.

## Live EPG

Primary file: `lib/live_epg.dart`

Current UI:
- `LiveEpgList`
- `LiveEpgRow`
- Channel logo/name on the left
- Current program title and local time range
- Next program line when available
- Loading and `No EPG data` row states
- Play affordance on the trailing side

Current interaction:
- `Home` renders this list only when Live + `ViewType.epg` is active.
- Tapping a row opens the same live playback path used by dense live rows.
- Duplicate stream variants still open `Choose version` before playback.
- The row list receives `resolvedChannelIds` so channels with cached no-data results do not keep showing loading during other fetches.

Strengths:
- Uses `SliverList.builder`, fixed row composition, and cached logos for large live lists.
- Keeps EPG UI separate from `ChannelTile`, avoiding accidental changes to Browse/All/Favorites/History.
- Loading/no-data/current/next states are widget-tested.

Limitations:
- No horizontal time grid.
- No date selector or manual refresh control.
- M3U sources show clean no-data until M3U/XMLTV support is added.

## MobileShellNav

Primary file: `lib/mobile_shell_nav.dart`

Current destinations:
- Live
- Movies
- Series
- Settings

Current behavior:
- Live, Movies, and Series rebuild the root `Home` with `ViewType.categories` and one media type.
- Settings opens `SettingsView`.
- Can block settings while startup refresh is running.
- The active section remains selected when `All media` is used; the selected chip communicates that search is global.

Strengths:
- Mobile shell now follows the reference app's media-first mental model.
- Uses Material `NavigationBar`.

Limitations vs Zen:
- Visual presentation is now media-aware at the browsing level, but still lacks detail pages and premium player overlays.
- Favorites and History are accessible but not yet polished as media-aware library surfaces.

Future direction:
- Phase 6 should split player architecture before adding custom Live/VOD overlays.
- Later phases can move Favorites/History into richer library screens if needed.

## Player UI

Primary file: `lib/player.dart`

Supporting files:
- `lib/player_controls/player_control_profile.dart`
- `lib/player_controls/material_player_controls.dart`
- `lib/player_controls/vod_transport.dart`
- `lib/player_controls/live_channel_context.dart`

Current UI:
- `Video` from `media_kit_video`
- `MaterialVideoControlsTheme`
- Top control row with back and title
- Bottom control row with subtitle, audio, and aspect ratio controls

Live-specific behavior:
- Seek bar hidden
- Seek gesture disabled
- Reconnect on completion
- Optional low-latency mpv settings
- Live behavior is now represented by `PlayerControlProfile.live`
- Live controls show a `LIVE x / y` badge when a loaded live context is available.
- Live controls include previous/next channel buttons when opened from a live list.

Movie-specific behavior:
- Resume position is restored.
- Position is saved on exit/dispose.
- VOD behavior is now represented by `PlayerControlProfile.vod`
- VOD controls add 10-second skip backward, restart, and 10-second skip forward.
- VOD skip targets are clamped through `vod_transport.dart`.

Current architecture split:
- `Player` still owns `media_kit` player/controller lifecycle, fullscreen entry/exit, HTTP header lookup, low-latency setup, reconnect, and resume persistence.
- `PlayerControlProfile` owns the Live vs VOD behavior flags for seeking, resume, and reconnect.
- `material_player_controls.dart` builds the current Material controls from a profile plus callbacks for exit, subtitles, audio, and zoom.
- `vod_transport.dart` owns pure seek target calculation for VOD skip buttons.
- `live_channel_context.dart` owns the loaded live channel list, current index, position label, and previous/next lookup.

Strengths:
- Uses a mature playback backend.
- Keeps live seek disabled.
- Handles resume and HTTP headers.
- Live and VOD control configuration is now separated from player lifecycle code.

Limitations:
- Live and VOD overlays are configured separately; VOD has basic transport buttons, and Live has previous/next channel controls.
- Controls are icon-only and sparse.
- No full live channel drawer.
- No rich VOD detail context overlay.
- No sleep timer or volume rail.
- Orientation restore/back behavior needs focused QA.

Future direction:
- Keep `media_kit` playback internals.
- Add custom overlays incrementally:
  - Later: full live channel drawer if needed.
  - Later: richer VOD title/context overlay if metadata exists.
  - Later: richer source-version labels if metadata exposes quality/container data.

## TV Home

Primary files:
- `lib/tv_home.dart`
- `lib/menu_tile.dart`

Current UI:
- Tile launcher with gradients and large icons.
- Focus/hover scale animation.
- First-level menu for Channels, Categories, Favorites, History, Settings.
- Second-level media type menu for All, Live, Movies, Series.

Strengths:
- TV mode is intentionally separated.
- Focus styling is already present.
- Uses large targets appropriate for remote input.

Limitations:
- Visual styling is more playful/basic than premium IPTV.
- Mobile and TV IA are not aligned.

Future direction:
- Do not refactor TV and mobile together in early phases.
- Preserve TV behavior while mobile shell is upgraded first.

## Setup

Primary file: `lib/setup.dart`

Current UI:
- Stepper-style source setup
- Linear progress indicator
- Shared axis transitions
- FormBuilder fields for source credentials
- File picker for local M3U

Strengths:
- Functional first-run flow.
- Supports three source types.
- Has basic validation and duplicate source-name check.

Limitations:
- Visual language is generic compared with target premium UX.
- Credential entry is still text-form heavy.

Future direction:
- Leave setup mostly unchanged until the main browsing/player experience is upgraded.
- Later polish copy, focus behavior, and validation states.

## Settings

Primary file: `lib/settings_view.dart`

Current UI:
- List-based settings screen.
- Toggles for force TV, low latency, refresh on start, and media visibility.
- Source list with refresh, edit, delete, enable/disable by long press.

Strengths:
- Contains most operational controls needed for current app.
- Source refresh and source editing are present.

Limitations:
- Long press to enable/disable source is hidden.
- Settings are dense but not grouped into sections.
- Source credentials are visible in normal edit fields.

Future direction:
- Defer large settings redesign.
- Add clearer source state controls when source management becomes part of the roadmap.

## Modals and Feedback

Files:
- `lib/whats_new_modal.dart`
- `lib/error.dart`
- `lib/correction_modal.dart`
- `lib/confirm_delete.dart`
- `lib/select_dialog.dart`
- `lib/loading.dart`
- `lib/channel_variant_picker.dart`

Current behavior:
- "What's new" dialog appears per version until dismissed.
- Error handling shows snackbar with a Details action and stack trace dialog.
- Loading uses `SpinKitPulsingGrid`.
- Destructive source delete uses a confirmation dialog.
- Duplicate source variants use a `Choose version` bottom sheet with current and favorite state indicators.

Strengths:
- Error details are available for debugging.
- Existing modals cover important operations.

Limitations:
- Visual tone is generic.
- Loading and empty states are not media-specific.

Future direction:
- Introduce polished loading, empty, and error states as part of each feature phase, not as a detached visual pass.

## Performance Notes

Current good practices:
- Sliver-based main list/grid.
- Builder-based rendering.
- Pagination.
- Stable keys for repeated channel and EPG rows.
- Guarded search/pagination requests through `LoadRequestGuard`.
- Cached network images with explicit memory cache sizing.
- Movie positions and history are persisted incrementally.
- Wide movie detail keeps Play/Resume controls before provider metadata so lazy metadata loading does not push the primary action down.

Current risks:
- `setState` scope in `Home` is broad.
- `ChannelTile` creates a `FocusNode` per visible item; acceptable for builder virtualization but should be monitored on TV/large grids.
- Rich poster rails can increase image memory pressure if added without fixed dimensions and cache discipline.
- Phase 12 ADB audit was visual/smoke oriented, not a full DevTools frame-timing profile.

Target standard:
- Maintain 60 fps as the default target and avoid architectural choices that prevent 120 fps on capable devices.
- Use `ListView.builder`, `SliverList`, `SliverGrid`, fixed extents, and stable keys for massive lists.
- Keep player, shell, and data loading rebuild scopes separate.
