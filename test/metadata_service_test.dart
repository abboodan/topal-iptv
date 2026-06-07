import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:topal_iptv/backend/db_factory.dart';
import 'package:topal_iptv/backend/metadata_service.dart';
import 'package:topal_iptv/backend/sql.dart';
import 'package:topal_iptv/backend/xtream.dart';
import 'package:topal_iptv/models/channel.dart';
import 'package:topal_iptv/models/filters.dart';
import 'package:topal_iptv/models/media_metadata.dart';
import 'package:topal_iptv/models/media_type.dart';
import 'package:topal_iptv/models/source.dart';
import 'package:topal_iptv/models/source_type.dart';
import 'package:topal_iptv/models/view_type.dart';

Future<void> useTemporaryDatabase(String testName) async {
  final tempDir = await Directory.systemTemp.createTemp(
    'topal_metadata_service_$testName',
  );
  addTearDown(() async {
    await DbFactory.resetForTesting();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });
  await DbFactory.usePathForTesting(p.join(tempDir.path, 'db.sqlite'));
}

Future<int> createSource(SourceType type) async {
  await Sql.commitWrite([
    Sql.getOrCreateSourceByName(
      Source(
        name: 'Metadata Service Source',
        sourceType: type,
        url: 'https://example.com/player_api.php',
        username: 'u',
        password: 'p',
      ),
    ),
  ]);
  return (await Sql.getSources()).single.id!;
}

Future<Channel> createMovie(int sourceId) async {
  await Sql.commitWrite([
    Sql.insertChannel(
      Channel(
        name: 'Service Movie',
        mediaType: MediaType.movie,
        sourceId: sourceId,
        favorite: false,
        streamId: 901,
        url: 'https://example.com/movie/u/p/901.mp4',
      ),
    ),
  ]);
  return (await Sql.search(
    Filters(
      query: 'Service Movie',
      viewType: ViewType.all,
      mediaTypes: [MediaType.movie],
      sourceIds: [sourceId],
    ),
  )).single;
}

MediaMetadata metadataFor(
  Channel channel, {
  String synopsis = 'Cached synopsis.',
  int fetchedAt = 1000,
}) {
  return MediaMetadata(
    channelId: channel.id!,
    sourceId: channel.sourceId,
    synopsis: synopsis,
    fetchedAt: fetchedAt,
  );
}

void main() {
  test('loadMediaMetadata skips fresh cache entries', () async {
    await useTemporaryDatabase('fresh');
    final sourceId = await createSource(SourceType.xtream);
    final movie = await createMovie(sourceId);
    await Sql.upsertMediaMetadata(metadataFor(movie, fetchedAt: 1000));

    var fetchCalls = 0;
    final metadata = await loadMediaMetadata(
      movie,
      now: DateTime.fromMillisecondsSinceEpoch(1000 * 1000, isUtc: true),
      fetchMetadata: (channel) async {
        fetchCalls++;
        return metadataFor(channel, synopsis: 'Fetched synopsis.');
      },
    );

    expect(fetchCalls, 0);
    expect(metadata?.synopsis, 'Cached synopsis.');
  });

  test('loadMediaMetadata fetches stale cache and stores the result', () async {
    await useTemporaryDatabase('stale');
    final sourceId = await createSource(SourceType.xtream);
    final movie = await createMovie(sourceId);
    await Sql.upsertMediaMetadata(metadataFor(movie, fetchedAt: 1000));

    final metadata = await loadMediaMetadata(
      movie,
      now: DateTime.fromMillisecondsSinceEpoch(
        (1000 + 8 * 24 * 3600) * 1000,
        isUtc: true,
      ),
      fetchMetadata: (channel) async {
        return metadataFor(
          channel,
          synopsis: 'Fetched synopsis.',
          fetchedAt: 2000,
        );
      },
    );

    expect(metadata?.synopsis, 'Fetched synopsis.');
    expect(
      (await Sql.getMediaMetadata(movie.id!))?.synopsis,
      'Fetched synopsis.',
    );
  });

  test('getXtreamMediaMetadata returns null for M3U sources', () async {
    await useTemporaryDatabase('m3u');
    final sourceId = await createSource(SourceType.m3uUrl);
    final movie = await createMovie(sourceId);

    expect(await getXtreamMediaMetadata(movie), isNull);
  });
}
