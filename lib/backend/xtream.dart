import 'dart:convert';

import 'package:topal_iptv/backend/sql.dart';
import 'package:topal_iptv/models/channel.dart';
import 'package:topal_iptv/models/channel_preserve.dart';
import 'package:topal_iptv/models/epg_program.dart';
import 'package:topal_iptv/models/media_metadata.dart';
import 'package:topal_iptv/models/media_type.dart';
import 'package:topal_iptv/models/source.dart';
import 'package:topal_iptv/models/source_type.dart';
import 'package:topal_iptv/models/xtream_types.dart';
import 'package:sqlite_async/sqlite_async.dart';
import 'package:http/http.dart' as http;

const String getLiveStreams = "get_live_streams";
const String getVods = "get_vod_streams";
const String getVodInfo = "get_vod_info";
const String getSeries = "get_series";
const String getSeriesInfo = "get_series_info";
const String getShortEpg = "get_short_epg";
const String getSeriesCategories = "get_series_categories";
const String getLiveStreamCategories = "get_live_categories";
const String getVodCategories = "get_vod_categories";
const String liveStreamExtension = "ts";

Future<void> getXtream(Source source, bool wipe) async {
  List<Future<void> Function(SqliteWriteContext, Map<String, String>)>
  statements = [];
  List<ChannelPreserve>? preserve;
  statements.add(Sql.getOrCreateSourceByName(source));
  if (wipe) {
    preserve = await Sql.getChannelsPreserve(source.id!);
    statements.add(Sql.wipeSource(source.id!));
  }
  source.urlOrigin = Uri.parse(source.url!).origin;
  var results = await Future.wait([
    getXtreamHttpData(getLiveStreams, source),
    getXtreamHttpData(getLiveStreamCategories, source),
    getXtreamHttpData(getVods, source),
    getXtreamHttpData(getVodCategories, source),
    getXtreamHttpData(getSeries, source),
    getXtreamHttpData(getSeriesCategories, source),
  ]);
  int failCount = 0;
  if (results[0] != null && results[1] != null) {
    try {
      processXtream(
        statements,
        processJsonList(results[0], XtreamStream.fromJson),
        processJsonList(results[1], XtreamCategory.fromJson),
        source,
        MediaType.livestream,
      );
    } catch (e) {
      failCount++;
    }
  } else {
    failCount++;
  }
  if (results[2] != null && results[3] != null) {
    try {
      processXtream(
        statements,
        processJsonList(results[2], XtreamStream.fromJson),
        processJsonList(results[3], XtreamCategory.fromJson),
        source,
        MediaType.movie,
      );
    } catch (e) {
      failCount++;
    }
  } else {
    failCount++;
  }

  if (results[4] != null && results[5] != null) {
    try {
      processXtream(
        statements,
        processJsonList(results[4], XtreamStream.fromJson),
        processJsonList(results[5], XtreamCategory.fromJson),
        source,
        MediaType.serie,
      );
    } catch (e) {
      failCount++;
    }
  } else {
    failCount++;
  }

  if (failCount > 1) {
    throw Exception("Failed to fetch source");
  }
  statements.add(Sql.updateGroups());
  if (preserve != null) {
    statements.add(Sql.restorePreserve(preserve));
  }
  await Sql.commitWrite(statements);
}

List<T> processJsonList<T>(
  List<dynamic> jsonList,
  T Function(Map<String, dynamic>) fromJson,
) {
  return jsonList
      .map((json) => fromJson(json as Map<String, dynamic>))
      .toList();
}

Future<dynamic> getXtreamHttpData(
  String action,
  Source source, [
  Map<String, String>? extraQueryParams,
]) async {
  try {
    var url = buildXtreamUrl(source, action, extraQueryParams);
    final response = await http.get(url);
    if (response.statusCode != 200) {
      return null;
    }
    return jsonDecode(response.body);
  } catch (_) {}
  return null;
}

String decodeXtreamEpgText(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return '';
  try {
    return utf8.decode(base64.decode(base64.normalize(text)));
  } catch (_) {
    return text;
  }
}

List<EpgProgram> xtreamEpgToPrograms(
  XtreamEPG epg,
  Channel channel, {
  required int fetchedAt,
}) {
  final channelId = channel.id;
  final streamId = channel.streamId;
  if (channelId == null || streamId == null) return [];

  final programs = <EpgProgram>[];
  for (final item in epg.epgListings) {
    final start = int.tryParse(item.startTimestamp ?? '');
    final stop = int.tryParse(item.stopTimestamp ?? '');
    if (start == null || stop == null || stop <= start) continue;
    final title = decodeXtreamEpgText(item.title);
    if (title.isEmpty) continue;
    programs.add(
      EpgProgram(
        channelId: channelId,
        sourceId: channel.sourceId,
        streamId: streamId,
        title: title,
        description: decodeXtreamEpgText(item.description),
        startTimestamp: start,
        stopTimestamp: stop,
        fetchedAt: fetchedAt,
      ),
    );
  }
  return programs;
}

Future<List<EpgProgram>> getShortEpgPrograms(
  Channel channel, {
  int limit = 4,
}) async {
  final streamId = channel.streamId;
  if (streamId == null || channel.id == null) return [];
  final source = await Sql.getSourceFromId(channel.sourceId);
  if (source.sourceType != SourceType.xtream) return [];
  final data = await getXtreamHttpData(getShortEpg, source, {
    'stream_id': streamId.toString(),
    'limit': limit.toString(),
  });
  if (data is! Map<String, dynamic>) return [];
  return xtreamEpgToPrograms(
    XtreamEPG.fromJson(data),
    channel,
    fetchedAt: Sql.epochSeconds(DateTime.now()),
  );
}

Future<MediaMetadata?> getXtreamMediaMetadata(Channel channel) async {
  final channelId = channel.id;
  if (channelId == null) return null;
  final source = await Sql.getSourceFromId(channel.sourceId);
  if (source.sourceType != SourceType.xtream) return null;

  final fetchedAt = Sql.epochSeconds(DateTime.now());
  if (channel.mediaType == MediaType.movie && channel.seriesId == null) {
    final streamId = channel.streamId;
    if (streamId == null) return null;
    final data = await getXtreamHttpData(getVodInfo, source, {
      'vod_id': streamId.toString(),
    });
    if (data is! Map<String, dynamic>) return null;
    return xtreamVodInfoToMetadata(data, channel, fetchedAt: fetchedAt);
  }

  if (channel.mediaType == MediaType.serie) {
    final seriesId = int.tryParse(channel.url ?? '');
    if (seriesId == null) return null;
    final data = await getXtreamHttpData(getSeriesInfo, source, {
      'series_id': seriesId.toString(),
    });
    if (data is! Map<String, dynamic>) return null;
    return xtreamSeriesInfoToMetadata(data, channel, fetchedAt: fetchedAt);
  }

  return null;
}

MediaMetadata? xtreamVodInfoToMetadata(
  Map<String, dynamic> data,
  Channel channel, {
  required int fetchedAt,
}) {
  final info = mergedXtreamInfo(data, extraKey: 'movie_data');
  return xtreamInfoToMetadata(info, channel, fetchedAt: fetchedAt);
}

MediaMetadata? xtreamSeriesInfoToMetadata(
  Map<String, dynamic> data,
  Channel channel, {
  required int fetchedAt,
}) {
  return xtreamInfoToMetadata(
    mapFromValue(data['info']),
    channel,
    fetchedAt: fetchedAt,
  );
}

Map<String, dynamic> mergedXtreamInfo(
  Map<String, dynamic> data, {
  String? extraKey,
}) {
  final extra = extraKey == null
      ? <String, dynamic>{}
      : mapFromValue(data[extraKey]);
  return {...extra, ...mapFromValue(data['info'])};
}

Map<String, dynamic> mapFromValue(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return {
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
  }
  return {};
}

MediaMetadata? xtreamInfoToMetadata(
  Map<String, dynamic> info,
  Channel channel, {
  required int fetchedAt,
}) {
  final channelId = channel.id;
  if (channelId == null) return null;
  return MediaMetadata(
    channelId: channelId,
    sourceId: channel.sourceId,
    synopsis: firstText(info, const [
      'plot',
      'description',
      'overview',
      'storyline',
    ]),
    year: metadataYear(
      firstText(info, const [
        'releaseDate',
        'releasedate',
        'release_date',
        'year',
      ]),
    ),
    rating: firstText(info, const ['rating', 'rating_5based']),
    durationSeconds: metadataDuration(
      firstValue(info, const ['duration_secs', 'duration_seconds', 'duration']),
    ),
    genres: metadataList(firstValue(info, const ['genre', 'genres'])),
    cast: metadataList(firstValue(info, const ['cast', 'actors'])),
    backdrop: firstImage(
      firstValue(info, const ['backdrop_path', 'backdrop', 'backdrop_url']),
    ),
    poster: firstImage(
      firstValue(info, const ['movie_image', 'cover', 'poster', 'stream_icon']),
    ),
    fetchedAt: fetchedAt,
  );
}

Object? firstValue(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value == null) continue;
    if (value is String && value.trim().isEmpty) continue;
    return value;
  }
  return null;
}

String? firstText(Map<String, dynamic> data, List<String> keys) {
  final value = firstValue(data, keys);
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String? metadataYear(String? value) {
  if (value == null) return null;
  final match = RegExp(r'\b(19|20)\d{2}\b').firstMatch(value);
  return match?.group(0);
}

int? metadataDuration(Object? value) {
  if (value == null) return null;
  if (value is num) return value > 0 ? value.round() : null;
  final text = value.toString().trim();
  final seconds = int.tryParse(text);
  if (seconds != null) return seconds > 0 ? seconds : null;

  final parts = text.split(':').map((part) => int.tryParse(part)).toList();
  if (parts.any((part) => part == null)) return null;
  if (parts.length == 3) {
    return parts[0]! * 3600 + parts[1]! * 60 + parts[2]!;
  }
  if (parts.length == 2) {
    return parts[0]! * 60 + parts[1]!;
  }
  return null;
}

List<String> metadataList(Object? value) {
  if (value == null) return [];
  final items = value is List
      ? value
      : value.toString().split(RegExp(r'[,/|]'));
  return items
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList();
}

String? firstImage(Object? value) {
  if (value == null) return null;
  if (value is List) {
    for (final item in value) {
      final text = item?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

void processXtream(
  List<Future<void> Function(SqliteWriteContext, Map<String, String>)>
  statements,
  List<XtreamStream> streams,
  List<XtreamCategory> cats,
  Source source,
  MediaType mediaType,
) {
  Map<String, String> catsMap = Map.fromEntries(
    cats.map(
      (x) => MapEntry(x.categoryId ?? "", x.categoryName ?? "Unknown Category"),
    ),
  );
  for (var live in streams) {
    if (live.name == null || live.name!.trim().isEmpty) continue;
    if (mediaType == MediaType.serie) {
      if (live.seriesId == null || live.seriesId!.isEmpty) continue;
    } else {
      if (live.streamId == null || live.streamId!.isEmpty) continue;
    }
    var cname = catsMap[live.categoryId ?? ""];
    try {
      var channel = xtreamToChannel(live, source, mediaType, cname);
      statements.add(Sql.insertChannel(channel));
    } catch (_) {}
  }
}

Channel xtreamToChannel(
  XtreamStream stream,
  Source source,
  MediaType streamType,
  String? categoryName,
) {
  return Channel(
    name: stream.name!.trim(),
    mediaType: streamType,
    sourceId: -1,
    favorite: false,
    group: categoryName,
    image: stream.streamIcon?.trim() ?? stream.cover?.trim(),
    url: streamType == MediaType.serie
        ? (stream.seriesId ?? "").toString()
        : getUrl(
            stream.streamId?.trim(),
            source,
            streamType,
            stream.containerExtension,
          ),
    streamId: int.tryParse(stream.streamId ?? "") ?? -1,
  );
}

String getUrl(
  String? streamId,
  Source source,
  MediaType streamType,
  String? extension,
) {
  return "${source.urlOrigin}/${getXtreamMediaTypeStr(streamType)}/${source.username}/${source.password}/$streamId.${extension ?? liveStreamExtension}";
}

String getXtreamMediaTypeStr(MediaType type) {
  switch (type) {
    case MediaType.livestream:
      return "live";
    case MediaType.movie:
      return "movie";
    case MediaType.serie:
      return "series";
    default:
      return "";
  }
}

Uri buildXtreamUrl(
  Source source,
  String action, [
  Map<String, String>? extraQueryParams,
]) {
  var params = {
    'username': source.username,
    'password': source.password,
    'action': action,
  };
  if (extraQueryParams != null) {
    params.addAll(extraQueryParams);
  }
  var url = Uri.parse(source.url!).replace(queryParameters: params);
  return url;
}

Future<void> getEpisodes(Channel channel) async {
  List<Future<void> Function(SqliteWriteContext, Map<String, String>)>
  statements = [];
  var seriesId = int.parse(channel.url!);
  var source = await Sql.getSourceFromId(channel.sourceId);
  source.urlOrigin = Uri.parse(source.url!).origin;
  var episodes = XtreamSeries.fromJson(
    await getXtreamHttpData(getSeriesInfo, source, {
      'series_id': seriesId.toString(),
    }),
  ).episodes;
  episodes.sort((a, b) {
    int seasonA = int.tryParse(a.season ?? "") ?? 0;
    int seasonB = int.tryParse(b.season ?? "") ?? 0;
    int seasonComparison = seasonA.compareTo(seasonB);
    if (seasonComparison != 0) {
      return seasonComparison;
    }
    int epA = int.tryParse(a.episodeNum ?? "") ?? 0;
    int epB = int.tryParse(b.episodeNum ?? "") ?? 0;
    return epA.compareTo(epB);
  });
  for (var episode in episodes) {
    if (episode.title == null || episode.title!.trim().isEmpty) continue;
    if (episode.id == null || episode.id!.isEmpty) continue;
    try {
      statements.add(
        Sql.insertChannel(episodeToChannel(episode, source, seriesId)),
      );
    } catch (_) {}
  }
  await Sql.commitWrite(statements);
}

Channel episodeToChannel(XtreamEpisode episode, Source source, int seriesId) {
  return Channel(
    image: episode.info?.movieImage,
    mediaType: MediaType.movie,
    name: episode.title!.trim(),
    sourceId: source.id!,
    favorite: false,
    url: getUrl(
      episode.id,
      source,
      MediaType.serie,
      episode.containerExtension,
    ),
    seriesId: seriesId,
  );
}
