# ADB UX Research: Zen Player vs Topal IPTV

Date: 2026-06-06

## Scope

This document records the dynamic ADB research performed on the same Android device with the same IPTV subscription configured in both apps.

Device:
- Model: OnePlus 9 Pro, `LE2123`
- Device id: `6a358f66`
- Resolution: `1080x2412`
- Density: `480`

Applications:
- Zen Player reference app: `app.zeniptv.mobile/.MainActivity`
- Topal IPTV current app: `com.topal.iptv/.MainActivity`

Evidence paths:
- Screenshots: `docs/research/screenshots/`
- UIAutomator dumps: `docs/research/uiautomator/`

## Method

The research used ADB to launch each application, navigate through touch input, capture screenshots, and dump UI hierarchy snapshots. Core flows covered:
- Launch and warm relaunch
- Global navigation shell
- Live TV categories and channel playback
- Movies/VOD discovery, detail, and playback
- Series discovery, detail, seasons, episodes, and playback
- Search behavior
- Player overlays for live and non-live content
- EPG mode entry points

## Zen Player Findings

### Launch and Profile

Reference evidence:
- `zen_00_launch.png`
- `zen_01_home.png`
- `zen_02_home_clear.png`

Observed behavior:
- Initial launch presents a profile gate: "Who's watching?", an existing profile, "New profile", and "Don't ask again".
- A developer message modal can appear above the home screen.
- Warm launch after reopen was visually fast, roughly in the 158-170 ms range from ADB activity timing. The first observed launch was roughly 289 ms.
- The first screen after clearing modals uses a premium dark visual language with strong poster/backdrop imagery.

UX implications:
- Zen separates user identity/state before content.
- Zen uses launch modals sparingly but visually integrated with the premium shell.
- Topal does not need profiles first, but should preserve a low-friction launch and avoid blocking content unnecessarily.

### Global Shell

Reference evidence:
- `zen_02_home_clear.png`
- `zen_03_live_home.png`
- `zen_18_movies_home.png`
- `zen_25_series_home.png`

Observed behavior:
- Top shell includes source/app switch affordance, search, profile, and settings.
- Bottom navigation exposes primary media modules: TV, Movies, Series.
- The selected bottom destination uses an icon plus label while inactive destinations are icon-forward.
- The shell keeps media type as a first-class navigation concept.

UX implications:
- The reference app does not treat IPTV as one mixed list. It starts with media-mode separation.
- Topal should evolve from `All/Categories/Favorites/History/Settings` toward a shell where Live, Movies, and Series are primary destinations, while favorites/history/settings remain secondary or contextual.

### Live TV

Reference evidence:
- `zen_03_live_home.png`
- `zen_04_live_browse.png`
- `zen_05_live_category.png`
- `zen_06_live_categories_scrolled.png`
- `zen_07_live_channel_list.png`
- `zen_15_columns_epg.png`
- `zen_16_columns_epg_populated.png`
- `zen_17_grid_epg_populated.png`

Observed behavior:
- Live TV opens with favorites as a primary state. If empty, Zen shows a clear empty state and a "Browse channels" call to action.
- Category navigation appears as horizontal chips/tabs. The captured subscription exposed a large category set, including 151 tabs in the UI hierarchy.
- Live browsing supports modes: Channels, Columns EPG, and Grid EPG.
- Channel rows use thumbnails/logos on the left, channel names on the right, and a dense list that still feels media-rich.
- In the tested sample, EPG layout modes changed the structure, but the selected category did not show a full populated time grid. Treat EPG data availability as subscription/channel dependent.

UX implications:
- Topal should keep live lists virtualized and category-scoped.
- EPG should be planned as a separate phase because it needs data model, caching, time layout, and missing-data states.
- Live favorites need a polished empty state and a fast route back to browsing.

### Live Player

Reference evidence:
- `zen_08_live_player_initial.png`
- `zen_10_live_player_loading.png`
- `zen_11_live_player_loaded.png`
- `zen_12_live_player_overlay.png`

Observed behavior:
- Opening some live channels can present a bottom sheet titled "Which version to launch?" with multiple source variants.
- The version picker states that the choice is remembered and long press can reopen it.
- The live player overlay is landscape-first and distinct from VOD:
  - Close button
  - Channel title
  - Center pause/play
  - Language and subtitles controls
  - Sleep timer
  - Volume rail
  - Fullscreen/aspect control
  - Bottom category/channel drawer
- Live player behavior is optimized around channel switching, not timeline scrubbing.

UX implications:
- Topal needs different player overlays for live and non-live content.
- Source/version selection should be considered when multiple equivalent streams exist.
- Live channel drawer is a major differentiator and should be implemented after the shell and live list are stable.

### Movies/VOD

Reference evidence:
- `zen_18_movies_home.png`
- `zen_19_movies_scrolled.png`
- `zen_20_movie_detail.png`
- `zen_22_movie_player_overlay.png`

Observed behavior:
- Movies home is discovery-first with rails such as Trending, Zen Access, Recently added, and category rows.
- Movie detail page uses:
  - Full-bleed backdrop/poster treatment
  - Strong gradient overlay
  - Large Start action
  - Bookmark/download actions
  - Metadata badges such as resolution, fps, year, duration, and rating
  - Synopsis, genres, and related media sections
- VOD playback overlay includes:
  - Title and synopsis context
  - Timeline and duration
  - Skip back/forward
  - Restart
  - Audio/subtitle/language controls
  - Sleep timer
  - Volume rail
  - Playback speed or gauge-like control
  - Aspect/fullscreen controls

UX implications:
- Topal should not open VOD directly into playback long-term. It needs a detail page and resume/start decision point.
- Player controls should be media-aware. Reusing one live-style overlay for movies leaves too much context missing.

### Series

Reference evidence:
- `zen_25_series_home.png`
- `zen_28_series_detail_opened.png`
- `zen_29_series_detail_scrolled.png`

Observed behavior:
- Series home follows the Movies pattern: support banner, trending rail, access rail, and discovery surfaces.
- Series detail includes:
  - Episode or show hero
  - Start action
  - Overview
  - Genres
  - Cast/people section
  - Seasons selector
  - Episode count
  - Episode rows with thumbnail and download action

UX implications:
- Topal already has lazy episode loading, so a professional series detail page can be added without replacing the import pipeline first.
- Season grouping should be explicit, not just a flat episode grid.

## Topal IPTV Baseline Findings

### Launch and Shell

Reference evidence:
- `topal_00_launch.png`
- `topal_03_home_clear.png`
- `topal_04_all_list.png`

Observed behavior:
- Cold launch reported around 247 ms. Warm relaunch reported around 149 ms.
- A "What's new" modal appears for the current version unless dismissed with "Don't show again".
- The mobile shell is functional and Material-oriented:
  - Search box at the top
  - Large row/card media items
  - Bottom navigation: All, Categories, Favorites, History, Settings
- Default view on the test device was Categories.
- The All view mixes raw tree/support/category/media content instead of splitting by Live, Movies, and Series.

UX implications:
- Startup performance is acceptable for the baseline.
- The current shell is structurally useful but does not match the reference app's media-first mental model.

### Browsing and Search

Reference evidence:
- `topal_04_all_list.png`
- `topal_06_search_bein_fixed.png`
- `topal_10_search_chum.png`
- `topal_15_search_halef_fixed.png`

Observed behavior:
- Search works and returns relevant results.
- Input through ADB inserted `%20` for spaces in some trials, so manual text-based ADB testing must account for that.
- Cards are large, simple rows on portrait. In landscape, the grid can become two columns.
- Current result cards show image, name, and favorite affordance, but little additional metadata.
- There are no discovery rails, category rails, or rich poster grids.

UX implications:
- Search should be preserved, but the result presentation needs media-aware cards and better density.
- Existing pagination and grid logic are a useful starting point for performance.

### Live Playback

Reference evidence:
- `topal_07_live_player_initial.png`
- `topal_08_live_player_after_wait.png`
- `topal_09_live_player_overlay.png`

Observed behavior:
- Live channels open directly into the player.
- No source-version picker was observed.
- The player uses a media_kit Material control shell:
  - Back/title top area
  - Center play/pause
  - Bottom icons for subtitle, audio, and aspect/fullscreen-style controls
- No live channel drawer, sleep timer, volume rail, or EPG/player-side channel context was observed.

UX implications:
- The current implementation is a valid playback baseline.
- A custom live overlay should be layered incrementally over media_kit rather than replacing playback internals early.

### VOD and Series Playback

Reference evidence:
- `topal_13_vod_overlay.png`
- `topal_16_series_after_tap.png`
- `topal_17_series_episode_player.png`
- `topal_18_series_episode_overlay.png`

Observed behavior:
- VOD opens directly to playback with no detail page.
- The VOD overlay is mostly the same control model as live, with a timeline/progress bar available through the media_kit controls.
- Series opens to an episode list/grid, not a full show detail page.
- Series episode playback uses the same player pattern as VOD.

UX implications:
- Topal has the correct minimum data path for series episodes, but lacks the professional detail layer.
- VOD and Series should gain detail pages before deep player customizations.

### State and Orientation

Observed behavior:
- After exiting player flows, the app was observed in landscape shell state during one test path.
- Back/close behavior should be audited during player work, especially orientation restore and route restore.

UX implications:
- Orientation handling should be part of the player overlay phase, not a separate late bugfix.

## Comparison Summary

| Area | Zen Player | Topal Baseline | Gap |
| --- | --- | --- | --- |
| Primary nav | TV, Movies, Series | All, Categories, Favorites, History, Settings | Media modes are not first-class on mobile |
| Home content | Discovery rails, banners, posters | Search plus list/grid | Needs media-aware surfaces |
| Live categories | Horizontal category tabs plus EPG modes | Category list and search | Needs live-specific browsing UI |
| Live player | Custom overlay with channel drawer and utilities | Generic media_kit controls | Needs custom live overlay |
| VOD detail | Rich detail page before playback | Direct playback | Needs detail/resume surface |
| Series detail | Overview, cast, seasons, episodes | Episode list/grid | Needs show detail and season grouping |
| EPG | Columns/Grid entry points | EPG model only, no UI observed | Needs backend, cache, and UI phase |
| Performance baseline | Fast launch, polished transitions | Fast launch, functional scroll | Preserve speed while upgrading UI |

## Implementation Takeaways

1. Do not rewrite the app in one pass. The current data path works and should be protected.
2. Start by making the mobile shell media-aware while keeping current filters and SQL.
3. Build detail pages before custom player overlays, because the detail pages require less playback risk and improve perceived quality quickly.
4. Keep player work separated by media type: Live, VOD, and Series episode playback have different controls.
5. Treat EPG as its own data and rendering project. It should not be bundled into the first navigation/UI pass.
6. Every phase should include ADB smoke testing on the established device.
