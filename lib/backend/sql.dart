import 'dart:collection';
import 'dart:convert';

import 'package:topal_iptv/backend/db_factory.dart';
import 'package:topal_iptv/models/channel.dart';
import 'package:topal_iptv/models/channel_http_headers.dart';
import 'package:topal_iptv/models/channel_preserve.dart';
import 'package:topal_iptv/models/epg_program.dart';
import 'package:topal_iptv/models/filters.dart';
import 'package:topal_iptv/models/id_data.dart';
import 'package:topal_iptv/models/media_type.dart';
import 'package:topal_iptv/models/media_metadata.dart';
import 'package:topal_iptv/models/source.dart';
import 'package:topal_iptv/models/source_type.dart';
import 'package:topal_iptv/models/view_type.dart';
import 'package:sqlite_async/sqlite3.dart';
import 'package:sqlite_async/sqlite_async.dart';

const int pageSize = 36;

class Sql {
  static Future<void> commitWrite(
    List<Future<void> Function(SqliteWriteContext, Map<String, String>)>
    commits,
  ) async {
    var db = await DbFactory.db;
    Map<String, String> memory = {};
    await db.writeTransaction((tx) async {
      for (var commit in commits) {
        await commit(tx, memory);
      }
    });
  }

  static Future<void> Function(SqliteWriteContext, Map<String, String> memory)
  insertChannel(Channel channel) {
    return (SqliteWriteContext tx, Map<String, String> memory) async {
      final sourceId = channel.sourceId == -1
          ? int.parse(memory['sourceId']!)
          : channel.sourceId;
      final variantKey = channelVariantKey(channel);
      await tx.execute(
        '''
        INSERT INTO channels (name, image, url, source_id, media_type, series_id, favorite, stream_id, group_name, variant_key)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT (source_id, variant_key)
        DO UPDATE SET
          name = excluded.name,
          url = excluded.url,
          group_name = excluded.group_name,
          media_type = excluded.media_type,
          stream_id = excluded.stream_id,
          image = excluded.image,
          series_id = excluded.series_id;
      ''',
        [
          channel.name,
          channel.image,
          channel.url,
          sourceId,
          channel.mediaType.index,
          channel.seriesId,
          channel.favorite,
          channel.streamId,
          channel.group,
          variantKey,
        ],
      );
      memory['lastChannelId'] = (await tx.get(
        '''
        SELECT id
        FROM channels
        WHERE source_id = ?
        AND variant_key = ?
      ''',
        [sourceId, variantKey],
      )).columnAt(0).toString();
    };
  }

  static String channelVariantKey(Channel channel) {
    final streamId = channel.streamId;
    if (channel.mediaType == MediaType.livestream &&
        streamId != null &&
        streamId >= 0) {
      return 'live:$streamId';
    }
    if (channel.mediaType == MediaType.movie && channel.seriesId != null) {
      return 'episode:${channel.seriesId}:${channel.url ?? channel.name}';
    }
    if (channel.mediaType == MediaType.movie &&
        streamId != null &&
        streamId >= 0) {
      return 'movie:$streamId';
    }
    if (channel.mediaType == MediaType.serie) {
      return 'series:${channel.url ?? channel.name}';
    }
    return 'url:${channel.mediaType.index}:${channel.url ?? channel.name}';
  }

  static Future<void> Function(SqliteWriteContext, Map<String, String>)
  updateGroups() {
    return (SqliteWriteContext tx, Map<String, String> memory) async {
      var sourceId = int.parse(memory['sourceId']!);
      await tx.execute(
        '''
      INSERT INTO groups (name, image, source_id, media_type)
      SELECT group_name, image, ?, media_type
      FROM channels
      WHERE source_id = ?
      AND group_name IS NOT NULL
      GROUP BY group_name
      ON CONFLICT(name, source_id)  
      DO UPDATE SET
          image = excluded.image,
          media_type = excluded.media_type;
    ''',
        [sourceId, sourceId],
      );
      await tx.execute(
        '''
      UPDATE channels
      SET group_id = (
        SELECT id
        FROM groups
        WHERE groups.name = channels.group_name
        AND groups.source_id = channels.source_id
        LIMIT 1
      )
      WHERE source_id = ?;
    ''',
        [sourceId],
      );
    };
  }

  static Future<void> Function(SqliteWriteContext, Map<String, String>)
  insertChannelHeaders(ChannelHttpHeaders headers) {
    return (SqliteWriteContext tx, Map<String, String> memory) async {
      await tx.execute(
        '''
          INSERT OR IGNORE INTO channel_http_headers (channel_id, referrer, user_agent, http_origin, ignore_ssl)
          VALUES (?, ?, ?, ?, ?)
        ''',
        [
          int.parse(memory['lastChannelId']!),
          headers.referrer,
          headers.userAgent,
          headers.httpOrigin,
          headers.ignoreSSL,
        ],
      );
    };
  }

  static Future<ChannelHttpHeaders?> getChannelHeaders(int channelId) async {
    var db = await DbFactory.db;
    var result = await db.getOptional(
      '''
        SELECT * FROM channel_http_headers
        WHERE channel_id = ?
        LIMIT 1
    ''',
      [channelId],
    );
    return result != null ? _rowToHeaders(result) : null;
  }

  static ChannelHttpHeaders _rowToHeaders(Row row) {
    return ChannelHttpHeaders(
      id: row.columnAt(0),
      channelId: row.columnAt(1),
      referrer: row.columnAt(2),
      userAgent: row.columnAt(3),
      httpOrigin: row.columnAt(4),
      ignoreSSL: row.columnAt(5),
    );
  }

  static Future<void> Function(SqliteWriteContext, Map<String, String>)
  getOrCreateSourceByName(Source source) {
    return (SqliteWriteContext tx, Map<String, String> memory) async {
      var sourceId = (await tx.getOptional(
        "SELECT id FROM sources WHERE name = ?",
        [source.name],
      ))?.columnAt(0);
      if (sourceId != null) {
        memory['sourceId'] = sourceId.toString();
        return;
      }
      await tx.execute(
        '''
            INSERT INTO sources (name, source_type, url, username, password) VALUES (?, ?, ?, ?, ?);
          ''',
        [
          source.name,
          source.sourceType.index,
          source.url,
          source.username,
          source.password,
        ],
      );
      memory['sourceId'] = (await tx.get(
        "SELECT last_insert_rowid();",
      )).columnAt(0).toString();
    };
  }

  static Future<List<Channel>> search(Filters filters) async {
    if (shouldSearchGroups(filters)) {
      return searchGroup(filters);
    }
    if (filters.mediaTypes == null ||
        filters.mediaTypes!.isEmpty ||
        filters.sourceIds == null ||
        filters.sourceIds!.isEmpty) {
      return [];
    }
    var db = await DbFactory.db;
    var offset = filters.page * pageSize - pageSize;
    var mediaTypes = filters.seriesId == null
        ? filters.mediaTypes!.map((x) => x.index)
        : [1];
    var query = (filters.query ?? "").trim();
    var keywords = filters.useKeywords
        ? query.split(" ").map((f) => "%$f%").toList()
        : ["%$query%"];
    var sqlQuery =
        '''
        SELECT * FROM channels 
        WHERE (${getKeywordsSql(keywords.length)})
        AND media_type IN (${generatePlaceholders(mediaTypes.length)})
        AND source_id IN (${generatePlaceholders(filters.sourceIds!.length)})
        AND url IS NOT NULL
    ''';
    List<Object> params = [];
    if (filters.viewType == ViewType.favorites && filters.seriesId == null) {
      sqlQuery += "\nAND favorite = 1";
    }
    if (filters.viewType == ViewType.history) {
      sqlQuery += "\nAND last_watched IS NOT NULL";
      sqlQuery += "\nORDER BY last_watched DESC";
    }
    if (filters.seriesId != null) {
      sqlQuery += "\nAND series_id = ?";
    } else if (filters.groupId != null) {
      sqlQuery += "\nAND group_id = ?";
    }
    if (filters.viewType != ViewType.history &&
        filters.mediaTypes!.length > 1 &&
        hasQuery(filters)) {
      sqlQuery += "\nORDER BY media_type, name COLLATE NOCASE";
    }
    sqlQuery += "\nLIMIT ?, ?";
    params.addAll(keywords);
    params.addAll(mediaTypes);
    params.addAll(filters.sourceIds!);
    if (filters.seriesId != null) {
      params.add(filters.seriesId!);
    } else if (filters.groupId != null) {
      params.add(filters.groupId!);
    }
    params.add(offset);
    params.add(pageSize);
    var results = await db.getAll(sqlQuery, params);
    return results.map(rowToChannel).toList();
  }

  static bool shouldSearchGroups(Filters filters) {
    return filters.viewType == ViewType.categories &&
        filters.groupId == null &&
        filters.seriesId == null &&
        !hasQuery(filters);
  }

  static bool hasQuery(Filters filters) {
    return filters.query?.trim().isNotEmpty == true;
  }

  static Channel rowToChannel(Row row) {
    return Channel(
      id: row.columnAt(0),
      name: row.columnAt(1),
      group: row.columnAt(2),
      image: row.columnAt(3),
      url: row.columnAt(4),
      mediaType: MediaType.values[row.columnAt(5)],
      sourceId: row.columnAt(6),
      favorite: row.columnAt(7) == 1,
      seriesId: row.columnAt(8),
      groupId: row.columnAt(9),
      streamId: row.columnAt(10),
      variantKey: row.columnAt(12),
    );
  }

  static EpgProgram rowToEpgProgram(Row row) {
    return EpgProgram(
      id: row.columnAt(0),
      channelId: row.columnAt(1),
      sourceId: row.columnAt(2),
      streamId: row.columnAt(3),
      title: row.columnAt(4),
      description: row.columnAt(5),
      startTimestamp: row.columnAt(6),
      stopTimestamp: row.columnAt(7),
      fetchedAt: row.columnAt(8),
    );
  }

  static MediaMetadata rowToMediaMetadata(Row row) {
    return MediaMetadata(
      id: row.columnAt(0),
      channelId: row.columnAt(1),
      sourceId: row.columnAt(2),
      synopsis: row.columnAt(3),
      year: row.columnAt(4),
      rating: row.columnAt(5),
      durationSeconds: row.columnAt(6),
      genres: decodeMetadataList(row.columnAt(7)),
      cast: decodeMetadataList(row.columnAt(8)),
      backdrop: row.columnAt(9),
      poster: row.columnAt(10),
      fetchedAt: row.columnAt(11),
    );
  }

  static List<String> decodeMetadataList(String? value) {
    if (value == null || value.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) return [];
      return decoded
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String encodeMetadataList(List<String> values) {
    return jsonEncode(
      values
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(),
    );
  }

  static int epochSeconds(DateTime dateTime) {
    return dateTime.toUtc().millisecondsSinceEpoch ~/ 1000;
  }

  static Future<void> replaceEpgPrograms(
    int channelId,
    List<EpgProgram> programs, {
    DateTime? fetchedAt,
  }) async {
    var db = await DbFactory.db;
    await db.writeTransaction((tx) async {
      await tx.execute(
        '''
        DELETE FROM epg_programs
        WHERE channel_id = ?
      ''',
        [channelId],
      );
      if (programs.isEmpty) {
        final channelRow = await tx.getOptional(
          '''
          SELECT source_id, COALESCE(stream_id, -1)
          FROM channels
          WHERE id = ?
        ''',
          [channelId],
        );
        if (channelRow == null) return;
        await tx.execute(
          '''
          INSERT INTO epg_programs (
            channel_id,
            source_id,
            stream_id,
            title,
            description,
            start_timestamp,
            stop_timestamp,
            fetched_at
          )
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
          [
            channelId,
            channelRow.columnAt(0),
            channelRow.columnAt(1),
            '',
            null,
            0,
            0,
            epochSeconds(fetchedAt ?? DateTime.now()),
          ],
        );
        return;
      }
      for (final program in programs) {
        await tx.execute(
          '''
          INSERT INTO epg_programs (
            channel_id,
            source_id,
            stream_id,
            title,
            description,
            start_timestamp,
            stop_timestamp,
            fetched_at
          )
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
          [
            channelId,
            program.sourceId,
            program.streamId,
            program.title,
            program.description,
            program.startTimestamp,
            program.stopTimestamp,
            program.fetchedAt,
          ],
        );
      }
    });
  }

  static Future<Map<int, EpgNowNext>> getNowNextEpgForChannels(
    List<Channel> channels, {
    DateTime? now,
  }) async {
    final ids = channels.map((channel) => channel.id).nonNulls.toList();
    if (ids.isEmpty) return {};
    final nowSeconds = epochSeconds(now ?? DateTime.now());
    var db = await DbFactory.db;
    var rows = await db.getAll(
      '''
      SELECT *
      FROM epg_programs
      WHERE channel_id IN (${generatePlaceholders(ids.length)})
      AND stop_timestamp > ?
      ORDER BY channel_id, start_timestamp
    ''',
      [...ids, nowSeconds],
    );
    final programsByChannel = <int, List<EpgProgram>>{};
    for (final program in rows.map(rowToEpgProgram)) {
      programsByChannel.putIfAbsent(program.channelId, () => []).add(program);
    }
    return {
      for (final entry in programsByChannel.entries)
        entry.key: _nowNextForPrograms(entry.value, nowSeconds),
    };
  }

  static EpgNowNext _nowNextForPrograms(
    List<EpgProgram> programs,
    int nowSeconds,
  ) {
    EpgProgram? current;
    EpgProgram? next;
    for (final program in programs) {
      if (current == null &&
          program.startTimestamp <= nowSeconds &&
          program.stopTimestamp > nowSeconds) {
        current = program;
        continue;
      }
      if (next == null && program.startTimestamp > nowSeconds) {
        next = program;
      }
      if (current != null && next != null) break;
    }
    return EpgNowNext(current: current, next: next);
  }

  static Future<bool> isEpgCacheFresh(
    int channelId, {
    DateTime? now,
    Duration ttl = const Duration(hours: 6),
  }) async {
    var db = await DbFactory.db;
    final row = await db.getOptional(
      '''
      SELECT MAX(fetched_at)
      FROM epg_programs
      WHERE channel_id = ?
    ''',
      [channelId],
    );
    final fetchedAt = row?.columnAt(0);
    if (fetchedAt == null) return false;
    final nowSeconds = epochSeconds(now ?? DateTime.now());
    return nowSeconds - (fetchedAt as int) <= ttl.inSeconds;
  }

  static Future<void> upsertMediaMetadata(MediaMetadata metadata) async {
    var db = await DbFactory.db;
    await db.execute(
      '''
      INSERT INTO media_metadata (
        channel_id,
        source_id,
        synopsis,
        year,
        rating,
        duration_seconds,
        genres,
        cast,
        backdrop,
        poster,
        fetched_at
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(channel_id)
      DO UPDATE SET
        source_id = excluded.source_id,
        synopsis = excluded.synopsis,
        year = excluded.year,
        rating = excluded.rating,
        duration_seconds = excluded.duration_seconds,
        genres = excluded.genres,
        cast = excluded.cast,
        backdrop = excluded.backdrop,
        poster = excluded.poster,
        fetched_at = excluded.fetched_at
    ''',
      [
        metadata.channelId,
        metadata.sourceId,
        metadata.synopsis,
        metadata.year,
        metadata.rating,
        metadata.durationSeconds,
        encodeMetadataList(metadata.genres),
        encodeMetadataList(metadata.cast),
        metadata.backdrop,
        metadata.poster,
        metadata.fetchedAt,
      ],
    );
  }

  static Future<MediaMetadata?> getMediaMetadata(int channelId) async {
    var db = await DbFactory.db;
    final row = await db.getOptional(
      '''
      SELECT *
      FROM media_metadata
      WHERE channel_id = ?
    ''',
      [channelId],
    );
    return row == null ? null : rowToMediaMetadata(row);
  }

  static Future<bool> isMediaMetadataFresh(
    int channelId, {
    DateTime? now,
    Duration ttl = const Duration(days: 7),
  }) async {
    var db = await DbFactory.db;
    final row = await db.getOptional(
      '''
      SELECT fetched_at
      FROM media_metadata
      WHERE channel_id = ?
    ''',
      [channelId],
    );
    final fetchedAt = row?.columnAt(0);
    if (fetchedAt == null) return false;
    final nowSeconds = epochSeconds(now ?? DateTime.now());
    return nowSeconds - (fetchedAt as int) <= ttl.inSeconds;
  }

  static Future<List<Channel>> getChannelVariants(Channel channel) async {
    final db = await DbFactory.db;
    final results = await db.getAll(
      '''
      SELECT *
      FROM channels
      WHERE source_id = ?
      AND name = ?
      AND media_type = ?
      AND url IS NOT NULL
      AND (
        (series_id IS NULL AND ? IS NULL)
        OR series_id = ?
      )
      ORDER BY name COLLATE NOCASE, variant_key COLLATE NOCASE
    ''',
      [
        channel.sourceId,
        channel.name,
        channel.mediaType.index,
        channel.seriesId,
        channel.seriesId,
      ],
    );
    return results.map(rowToChannel).toList();
  }

  static String generatePlaceholders(int size) {
    return List.filled(size, "?").join(",");
  }

  static String getKeywordsSql(int size) {
    return List.generate(size, (_) => "name LIKE ?").join(" AND ");
  }

  static Future<List<Channel>> searchGroup(Filters filters) async {
    if (filters.mediaTypes == null ||
        filters.mediaTypes!.isEmpty ||
        filters.sourceIds == null ||
        filters.sourceIds!.isEmpty) {
      return [];
    }
    var db = await DbFactory.db;
    var offset = filters.page * pageSize - pageSize;
    var query = (filters.query ?? "").trim();
    var keywords = filters.useKeywords
        ? query.split(" ").map((f) => "%$f%").toList()
        : ["%$query%"];
    var mediaTypes = filters.mediaTypes!.map((x) => x.index);
    var sqlQuery =
        '''
        SELECT * FROM groups 
        WHERE (${getKeywordsSql(keywords.length)})
        AND (media_type IS NULL OR media_type IN (${generatePlaceholders(mediaTypes.length)}))
        AND source_id IN (${generatePlaceholders(filters.sourceIds!.length)})
        LIMIT ?, ?
    ''';
    List<Object> params = [];
    params.addAll(keywords);
    params.addAll(mediaTypes);
    params.addAll(filters.sourceIds!);
    params.add(offset);
    params.add(pageSize);
    var results = await db.getAll(sqlQuery, params);
    return results.map(groupChannelToRow).toList();
  }

  static Channel groupChannelToRow(Row row) {
    return Channel(
      id: row.columnAt(0),
      name: row.columnAt(1),
      image: row.columnAt(2),
      sourceId: row.columnAt(3),
      favorite: false,
      mediaType: MediaType.group,
    );
  }

  static Future<bool> sourceNameExists(String? name) async {
    var db = await DbFactory.db;
    var result = await db.getOptional(
      '''
      SELECT 1
      FROM sources
      WHERE name = ?
    ''',
      [name],
    );
    return result?.columnAt(0) == 1;
  }

  static Future<List<Source>> getSources() async {
    var db = await DbFactory.db;
    var results = await db.getAll('''
      SELECT * 
      FROM sources 
    ''');
    return results.map(rowToSource).toList();
  }

  static Source rowToSource(Row row) {
    return Source(
      id: row.columnAt(0),
      name: row.columnAt(1),
      sourceType: SourceType.values[row.columnAt(2)],
      url: row.columnAt(3),
      username: row.columnAt(4),
      password: row.columnAt(5),
      enabled: row.columnAt(6) == 1,
    );
  }

  static Future<List<IdData<SourceType>>> getEnabledSourcesMinimal() async {
    var db = await DbFactory.db;
    var results = await db.getAll('''
      SELECT id, source_type
      FROM sources 
      WHERE enabled = 1
    ''');
    return results.map(rowToSourceMinimal).toList();
  }

  static IdData<SourceType> rowToSourceMinimal(Row row) {
    return IdData(
      id: row.columnAt(0),
      data: SourceType.values[row.columnAt(1)],
    );
  }

  static Future<bool> hasSources() async {
    var db = await DbFactory.db;
    var result = await db.getOptional('''
      SELECT 1
      FROM sources
      LIMIT 1
    ''');
    return result?.columnAt(0) == 1;
  }

  static Future<void> favoriteChannel(int channelId, bool favorite) async {
    var db = await DbFactory.db;
    await db.execute(
      '''
      UPDATE channels
      SET favorite = ?
      WHERE id = ?
    ''',
      [favorite ? 1 : 0, channelId],
    );
  }

  static Future<HashMap<String, String>> getSettings() async {
    var db = await DbFactory.db;
    var results = await db.getAll('''SELECT key, value FROM Settings''');
    return HashMap.fromEntries(
      results.map((f) => MapEntry(f.columnAt(0), f.columnAt(1))),
    );
  }

  static Future<void> updateSettings(HashMap<String, String> settings) async {
    var db = await DbFactory.db;
    await db.writeTransaction((tx) async {
      for (var entry in settings.entries) {
        await tx.execute(
          '''
        INSERT INTO Settings (key, value)
        VALUES (?, ?)
        ON CONFLICT(key) DO UPDATE SET value = ?''',
          [entry.key, entry.value, entry.value],
        );
      }
    });
  }

  static Future<void> deleteSource(int sourceId) async {
    var db = await DbFactory.db;
    await db.writeTransaction((tx) async {
      await tx.execute("DELETE FROM media_metadata WHERE source_id = ?", [
        sourceId,
      ]);
      await tx.execute("DELETE FROM epg_programs WHERE source_id = ?", [
        sourceId,
      ]);
      await tx.execute("DELETE FROM channels WHERE source_id = ?", [sourceId]);
      await tx.execute("DELETE FROM groups WHERE source_id = ?", [sourceId]);
      await tx.execute("DELETE FROM sources WHERE id = ?", [sourceId]);
    });
  }

  static Future<void> Function(SqliteWriteContext, Map<String, String>)
  wipeSource(int sourceId) {
    return (SqliteWriteContext tx, Map<String, String> memory) async {
      await tx.execute(
        '''
        DELETE FROM media_metadata
        WHERE source_id = ?
      ''',
        [sourceId],
      );
      await tx.execute(
        '''
        DELETE FROM epg_programs
        WHERE source_id = ?
      ''',
        [sourceId],
      );
      await tx.execute(
        '''
        DELETE FROM channels 
        WHERE source_id = ? 
      ''',
        [sourceId],
      );
      await tx.execute(
        '''
        DELETE FROM groups
        WHERE source_id = ?
      ''',
        [sourceId],
      );
    };
  }

  static Future<void> updateSource(Source source) async {
    var db = await DbFactory.db;
    await db.execute(
      '''
      UPDATE sources
      SET url = ?, username = ?, password = ?
      WHERE id = ?
    ''',
      [source.url, source.username, source.password, source.id],
    );
  }

  static Future<Source> getSourceFromId(int id) async {
    var db = await DbFactory.db;
    var result = await db.get('''SELECT * FROM sources WHERE id = ?''', [id]);
    return rowToSource(result);
  }

  static Future<void> setSourceEnabled(bool enabled, int sourceId) async {
    var db = await DbFactory.db;
    await db.execute(
      '''
      UPDATE sources 
      SET enabled = ? 
      WHERE id = ?
    ''',
      [enabled, sourceId],
    );
  }

  static Future setPosition(int channelId, int seconds) async {
    var db = await DbFactory.db;
    await db.execute(
      '''
      INSERT INTO movie_positions (channel_id, position)
      VALUES (?, ?)
      ON CONFLICT (channel_id)
      DO UPDATE SET
      position = excluded.position;
    ''',
      [channelId, seconds],
    );
  }

  static Future<int?> getPosition(int channelId) async {
    var db = await DbFactory.db;
    var result = await db.getOptional(
      '''
      SELECT position FROM movie_positions
      WHERE channel_id = ?
    ''',
      [channelId],
    );
    return result?.columnAt(0);
  }

  static Future<void> addToHistory(int id) async {
    var db = await DbFactory.db;
    await db.execute(
      '''
      UPDATE channels
      SET last_watched = strftime('%s', 'now')
      WHERE id = ?
    ''',
      [id],
    );
    await db.execute('''
      UPDATE channels
      SET last_watched = NULL
      WHERE last_watched IS NOT NULL
		  AND id NOT IN (
				SELECT id 
				FROM channels
				WHERE last_watched IS NOT NULL
				ORDER BY last_watched DESC
				LIMIT 36
		  )
    ''');
  }

  static Future<List<ChannelPreserve>> getChannelsPreserve(int sourceId) async {
    var db = await DbFactory.db;
    var results = await db.getAll(
      '''
      SELECT name, variant_key, favorite, last_watched
      FROM channels
      WHERE (favorite = 1 OR last_watched IS NOT NULL) AND source_id = ?
    ''',
      [sourceId],
    );
    return results.map(rowToChannelPreserve).toList();
  }

  static ChannelPreserve rowToChannelPreserve(Row row) {
    return ChannelPreserve(
      name: row.columnAt(0),
      variantKey: row.columnAt(1),
      favorite: row.columnAt(2),
      lastWatched: row.columnAt(3),
    );
  }

  static Future<void> Function(SqliteWriteContext, Map<String, String>)
  restorePreserve(List<ChannelPreserve> preserve) {
    return (SqliteWriteContext tx, Map<String, String> memory) async {
      final sourceId = int.parse(memory['sourceId']!);
      for (var channel in preserve) {
        await tx.execute(
          '''
          UPDATE channels
          SET favorite = ?, last_watched = ?
          WHERE variant_key = ?
          AND source_id = ?
        ''',
          [channel.favorite, channel.lastWatched, channel.variantKey, sourceId],
        );
      }
    };
  }
}
