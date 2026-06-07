# Topal IPTV Data Layer State

Date: 2026-06-07

## Purpose

This document maps the current persistence, import, query, and data model behavior before incremental UX work begins.

## Storage

Primary file: `lib/backend/db_factory.dart`

Database:
- SQLite file at `${Utils.appDir}/db.sqlite`
- Accessed through `sqlite_async`
- Singleton-style database factory through `DbFactory.db`

Current migrations:
- Migration 1: base tables, indexes, unique constraints
- Migration 2: `channels.last_watched`
- Migration 3: `groups.media_type`
- Migration 4: `channels.variant_key`, channel uniqueness changed from `(name, source_id)` to `(source_id, variant_key)`
- Migration 5: `epg_programs` table and EPG lookup/cache indexes
- Migration 6: `media_metadata` table for lazy VOD/Series metadata cache

## Tables

### sources

Columns:
- `id`
- `name`
- `source_type`
- `url`
- `username`
- `password`
- `enabled`

Purpose:
- Stores Xtream, M3U URL, and local M3U source definitions.

### channels

Columns:
- `id`
- `name`
- `group_name`
- `image`
- `url`
- `media_type`
- `source_id`
- `favorite`
- `series_id`
- `group_id`
- `stream_id`
- `last_watched`
- `variant_key`

Purpose:
- Stores live channels, movies, series roots, and series episodes.
- This is the core overloaded media table.

Important constraints/indexes:
- Unique index on `(source_id, variant_key)`
- Indexes on source, favorite, series, group, media type, stream id, group name, last watched, and variant key.

### groups

Columns:
- `id`
- `name`
- `image`
- `source_id`
- `media_type`

Purpose:
- Stores category/group rows derived from imported channels.

Important constraints/indexes:
- Unique index on `(name, source_id)`
- Indexes on name, source, and media type.

### channel_http_headers

Columns:
- `id`
- `channel_id`
- `referrer`
- `user_agent`
- `http_origin`
- `ignore_ssl`

Purpose:
- Persists per-channel playback headers parsed from M3U `#EXTVLCOPT` lines.

### epg_programs

Columns:
- `id`
- `channel_id`
- `source_id`
- `stream_id`
- `title`
- `description`
- `start_timestamp`
- `stop_timestamp`
- `fetched_at`

Purpose:
- Stores short live EPG windows for loaded Live channels.
- Supports now/next queries and a 6-hour cache TTL.
- Uses a zero-time empty marker row when a provider returns no programs, so the app does not repeatedly refetch no-data channels while scrolling.

Important constraints/indexes:
- Foreign keys to `channels` and `sources` with cascade delete.
- Indexes on channel, source, stream, time window, and fetched timestamp.

### movie_positions

Columns:
- `id`
- `channel_id`
- `position`

Purpose:
- Stores resume position for movies and series episodes treated as movie media.

### media_metadata

Columns:
- `id`
- `channel_id`
- `source_id`
- `synopsis`
- `year`
- `rating`
- `duration_seconds`
- `genres`
- `cast`
- `backdrop`
- `poster`
- `fetched_at`

Purpose:
- Stores lazily fetched Xtream metadata for top-level movies and series.
- `genres` and `cast` are JSON-encoded string lists.
- Cache freshness defaults to 7 days through `metadata_service.dart`.

Important constraints/indexes:
- Unique index on `channel_id`
- Indexes on source and fetched timestamp
- Foreign keys to `channels` and `sources` with cascade delete, plus explicit source wipe/delete cleanup

### settings

Columns:
- `key`
- `value`

Purpose:
- Stores app settings as string key/value pairs.

## Core Models

### Channel

File: `lib/models/channel.dart`

Fields:
- `id`
- `name`
- `groupId`
- `group`
- `image`
- `url`
- `mediaType`
- `sourceId`
- `favorite`
- `seriesId`
- `streamId`
- `variantKey`

Notes:
- Represents group rows, live channels, movies, series roots, and episodes.
- `mediaType` determines how the UI should interpret the row.

### EpgProgram

File: `lib/models/epg_program.dart`

Fields:
- `id`
- `channelId`
- `sourceId`
- `streamId`
- `title`
- `description`
- `startTimestamp`
- `stopTimestamp`
- `fetchedAt`

Notes:
- Timestamp fields are stored as UTC epoch seconds.
- `startTime` and `stopTime` convert to device-local `DateTime` for display.
- `EpgNowNext` groups the current and next program for UI rendering.

### MediaMetadata

File: `lib/models/media_metadata.dart`

Fields:
- `id`
- `channelId`
- `sourceId`
- `synopsis`
- `year`
- `rating`
- `durationSeconds`
- `genres`
- `cast`
- `backdrop`
- `poster`
- `fetchedAt`

Notes:
- Represents optional provider metadata; all display fields except ids and `fetchedAt` can be absent.
- `hasDetails` lets detail pages avoid rendering empty metadata sections.

### MediaType

File: `lib/models/media_type.dart`

Values:
- `livestream`
- `movie`
- `serie`
- `group`

### Filters

File: `lib/models/filters.dart`

Fields:
- `query`
- `sourceIds`
- `mediaTypes`
- `viewType`
- `page`
- `seriesId`
- `groupId`
- `useKeywords`

Purpose:
- Drives SQL search and pagination.

### HomeManager and Node

Files:
- `lib/models/home_manager.dart`
- `lib/models/node.dart`
- `lib/models/node_type.dart`

Purpose:
- Wraps `Filters` and optional nested navigation node.
- Nodes are either category or series.

### Source

Files:
- `lib/models/source.dart`
- `lib/models/source_type.dart`

Purpose:
- Stores provider credentials and type.

Source types:
- `xtream`
- `m3uUrl`
- `m3u`

### Settings

File: `lib/models/settings.dart`

Fields:
- `defaultView`
- `refreshOnStart`
- `showLivestreams`
- `lowLatency`
- `showMovies`
- `showSeries`
- `forceTVMode`

Settings also expose `getMediaTypes()` to derive visible media types.

## Query Layer

Primary file: `lib/backend/sql.dart`

Important constants:
- `pageSize = 36`

Main query methods:
- `search(Filters filters)`
- `searchGroup(Filters filters)`
- `getChannelVariants(Channel channel)`
- `replaceEpgPrograms(int channelId, List<EpgProgram> programs)`
- `getNowNextEpgForChannels(List<Channel> channels)`
- `isEpgCacheFresh(int channelId)`
- `getMediaMetadata(int channelId)`
- `upsertMediaMetadata(MediaMetadata metadata)`
- `isMediaMetadataFresh(int channelId)`
- `channelVariantKey(Channel channel)`
- `favoriteChannel(int channelId, bool favorite)`
- `addToHistory(int id)`
- `setPosition(int channelId, int seconds)`
- `getPosition(int channelId)`
- `getChannelHeaders(int channelId)`
- Source CRUD and enabled-source helpers
- Settings read/write helpers

Search behavior:
- Categories root uses `searchGroup()` when `viewType == ViewType.categories` and no `groupId` or `seriesId`.
- Categories root uses channel search instead of group search when a non-empty query exists. This keeps Browse useful for searching movies, series, or live channels inside the current media section.
- Normal search queries `channels`.
- `favorites` filters rows with `favorite = 1`.
- `history` filters rows with `last_watched IS NOT NULL` and orders by newest first.
- `seriesId` filters episode rows.
- `groupId` filters channels/movies/series within a category.
- Pagination uses SQLite `LIMIT offset, pageSize`.

Variant behavior:
- `channelVariantKey()` derives stable identity for import/upsert:
  - Live Xtream rows: `live:{streamId}`
  - Top-level Xtream movies: `movie:{streamId}`
  - Series episodes: `episode:{seriesId}:{url}`
  - Series roots: `series:{url}`
  - M3U/fallback rows: `url:{mediaType.index}:{url}`
- `insertChannel()` upserts by `(source_id, variant_key)`, so duplicate display names can coexist when their stream ids or URLs differ.
- `getChannelVariants()` returns same-name, same-source, same-media rows with the same `series_id` null/non-null shape for the playback picker.

Keyword behavior:
- When `useKeywords` is true, query text is split on spaces and each token must match `name LIKE ?`.
- Otherwise, the full query becomes a single `LIKE` expression.

Global media search:
- The mobile UI can pass all enabled media types to `Sql.search()` through the `All media` chip.
- When multiple media types are searched with a query, SQL orders by `media_type` then name so mixed results are stable and easier to scan.

## Import Flow: Xtream

Primary file: `lib/backend/xtream.dart`

Source actions fetched:
- `get_live_streams`
- `get_live_categories`
- `get_vod_streams`
- `get_vod_categories`
- `get_series`
- `get_series_categories`
- `get_short_epg` is fetched lazily per loaded live channel, not during source import.
- `get_vod_info` is fetched lazily per opened movie detail page.
- `get_series_info` is reused for lazy series metadata and lazy episode import.

Flow:
1. Get or create source by name.
2. If refreshing, preserve favorites/history and wipe existing source rows.
3. Fetch live streams/categories, VOD streams/categories, and series/categories concurrently.
4. Convert each stream into a `Channel`.
5. Insert/update channels by variant key.
6. Rebuild groups.
7. Restore favorites/history by variant key when refreshing.

URL construction:
- Live: `{origin}/live/{username}/{password}/{streamId}.{extension}`
- Movie: `{origin}/movie/{username}/{password}/{streamId}.{extension}`
- Series episode: `{origin}/series/{username}/{password}/{episodeId}.{extension}`

Current metadata captured:
- Stream id
- Name
- Category id/name
- Stream icon or cover
- Series id
- Container extension

Lazy metadata captured when available:
- Synopsis/plot/description
- Genre list
- Cast/actors list
- Rating
- Release year
- Duration in seconds for VOD
- Backdrop
- Poster/cover

Current metadata not persisted:
- Full credits
- Multiple backdrops
- Episode-specific rich metadata UI
- External metadata from TMDB or other APIs

Short EPG behavior:
- `getShortEpgPrograms()` calls Xtream `get_short_epg` with live `stream_id` and a small `limit`.
- EPG titles/descriptions tolerate either Base64-encoded or plain provider text.
- Invalid or backwards timestamps are ignored.
- Non-Xtream sources return an empty EPG result and do not make Xtream requests.

## Lazy Series Episode Flow

Primary files:
- `lib/channel_tile.dart`
- `lib/backend/xtream.dart`
- `lib/memory.dart`

Flow:
1. Tapping a series card checks `refreshedSeries`.
2. If the series was not fetched during the current runtime, `getEpisodes(channel)` is called.
3. `get_series_info` is fetched with `series_id`.
4. Episodes are flattened from the API response.
5. Episodes are sorted by season then episode number.
6. Episodes are inserted as `Channel` rows with `MediaType.movie` and `seriesId`.
7. The UI navigates into a series node and displays those episode rows.

Implication:
- Episode data path already exists and can support a better series detail page.
- Show-level metadata is not currently stored, so initial detail pages may be limited unless the import/data model is extended.

## Import Flow: M3U

Primary file: `lib/backend/m3u.dart`

Flow:
1. Read a local M3U file or downloaded M3U URL line by line.
2. Parse `#EXTINF` metadata.
3. Parse optional `#EXTVLCOPT` HTTP headers.
4. Determine media type from URL extension:
   - `.mp4` or `.mkv` => movie
   - otherwise => livestream
5. Insert/update channels by variant key.
6. Rebuild groups.
7. Restore favorites/history by variant key on refresh.

Parsed fields:
- `tvg-name`
- trailing name fallback
- `tvg-id` fallback
- `tvg-logo`
- `group-title`
- `http-origin`
- `http-referrer`
- `http-user-agent`

Current limitations:
- M3U series are not modeled separately.
- M3U movie detection is extension-based only.

## Playback Data

Player reads:
- `Channel.url`
- `Channel.name`
- `Channel.mediaType`
- optional `ChannelHttpHeaders`
- saved movie position
- low latency setting

Player writes:
- movie position on exit/dispose
- history is written before opening player from `ChannelTile`

Important behavior:
- `addToHistory()` keeps only the newest 36 watched items.
- Resume positions are keyed by `channel_id`.

## Metadata State

Primary files:
- `lib/models/media_metadata.dart`
- `lib/backend/metadata_service.dart`
- `lib/backend/xtream.dart`
- `lib/backend/sql.dart`

Implemented behavior:
- Movie and series detail pages call `loadMediaMetadata()` lazily.
- Fresh cache is returned without a provider request.
- Stale or missing cache uses Xtream only when the source type is `xtream`.
- M3U sources return no metadata cleanly and keep the older simple detail UI.
- Parser helpers tolerate provider field variants such as `plot`, `description`, `releaseDate`, `releasedate`, `duration_secs`, `rating`, `genre`, `cast`, `actors`, and `backdrop_path`.
- Source wipe/delete removes metadata rows.

Current limits:
- Metadata is not imported during full source refresh.
- Episode rows still play directly and do not have a separate rich episode detail route.

## Settings Data

Primary files:
- `lib/backend/settings_service.dart`
- `lib/backend/sql.dart`

Settings are converted from strings to typed values manually.

Known keys:
- `defaultView`
- `refreshOnStart`
- `showLivestreams`
- `showMovies`
- `showSeries`
- `lastSeenVersion`
- `forceTVMode`
- `streamCaching`

## EPG State

Primary files:
- `lib/models/epg_program.dart`
- `lib/models/xtream_types.dart`
- `lib/backend/epg_service.dart`
- `lib/backend/xtream.dart`
- `lib/backend/sql.dart`

Implemented behavior:
- `ViewType.epg` is Live-only in the mobile shell.
- `refreshEpgForChannels()` fetches short EPG lazily for loaded live rows.
- Cache TTL defaults to 6 hours.
- Fetch concurrency is bounded to 3 channels at a time.
- `Sql.replaceEpgPrograms()` replaces the cached window per channel and records no-data fetches with an empty marker row.
- `Sql.getNowNextEpgForChannels()` returns the current and next program for each loaded channel.
- Source wipe/delete removes matching EPG rows.

Current limits:
- V1 only supports short Xtream EPG for Live channels.
- M3U EPG, full XMLTV imports, a timeline grid, and player-side EPG overlay are not implemented yet.

## Data-Layer Risks to Verify Before Expansion

1. `Channel` is overloaded and will need careful UI typing to avoid accidental behavior changes.
2. Category/group generation SQL in `Sql.updateGroups()` should be verified before any import refactor.
3. Duplicate stream variants with the exact same display name are now representable, but the main browsing lists still show duplicate rows rather than deduplicated groups.
4. Xtream VOD and series metadata are lazy detail-page data, not full import-time data.
5. EPG V1 is intentionally short-window and Live-only; full grid/timeline and player overlay need a later phase.
6. Refresh-all currently loops sources sequentially, which may block startup when `refreshOnStart` is enabled.
7. Search queries are simple `LIKE` queries. They may be acceptable for current datasets, but future search UX may need ranked or normalized matching.

## Preservation Rules

Do not break:
- Source setup
- Source refresh
- Favorites across refresh, keyed by `variant_key`
- History across refresh, keyed by `variant_key`
- Movie resume
- HTTP header playback
- Lazy episode loading
- Existing enabled/disabled source filtering
- Existing settings keys

For each data-layer change:
- Add or migrate without deleting old fields.
- Keep compatibility with existing `Channel` rows.
- Verify import with the existing configured subscription.
- Smoke-test Live, VOD, Series, Favorites, History, and Search after the change.
