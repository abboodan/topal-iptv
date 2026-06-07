import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:topal_iptv/backend/db_factory.dart';
import 'package:topal_iptv/backend/sql.dart';
import 'package:topal_iptv/models/channel.dart';
import 'package:topal_iptv/models/filters.dart';
import 'package:topal_iptv/models/media_metadata.dart';
import 'package:topal_iptv/models/media_type.dart';
import 'package:topal_iptv/models/source.dart';
import 'package:topal_iptv/models/source_type.dart';
import 'package:topal_iptv/models/view_type.dart';

Future<void> useTemporaryDatabase(String testName) async {
  final tempDir = await Directory.systemTemp.createTemp(
    'topal_metadata_$testName',
  );
  addTearDown(() async {
    await DbFactory.resetForTesting();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });
  await DbFactory.usePathForTesting(p.join(tempDir.path, 'db.sqlite'));
}

Future<int> createSource() async {
  await Sql.commitWrite([
    Sql.getOrCreateSourceByName(
      Source(
        name: 'Metadata Source',
        sourceType: SourceType.xtream,
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
        name: 'Metadata Movie',
        mediaType: MediaType.movie,
        sourceId: sourceId,
        favorite: false,
        streamId: 900,
        url: 'https://example.com/movie/u/p/900.mp4',
      ),
    ),
  ]);
  return (await Sql.search(
    Filters(
      query: 'Metadata Movie',
      viewType: ViewType.all,
      mediaTypes: [MediaType.movie],
      sourceIds: [sourceId],
    ),
  )).single;
}

MediaMetadata metadataFor(
  Channel channel, {
  String synopsis = 'A careful synopsis.',
  int fetchedAt = 1000,
}) {
  return MediaMetadata(
    channelId: channel.id!,
    sourceId: channel.sourceId,
    synopsis: synopsis,
    year: '2026',
    rating: '8.4',
    durationSeconds: 5400,
    genres: const ['Drama', 'Mystery'],
    cast: const ['Actor One', 'Actor Two'],
    backdrop: 'https://example.com/backdrop.jpg',
    poster: 'https://example.com/poster.jpg',
    fetchedAt: fetchedAt,
  );
}

void main() {
  test('upsertMediaMetadata inserts and updates metadata by channel', () async {
    await useTemporaryDatabase('upsert');
    final sourceId = await createSource();
    final movie = await createMovie(sourceId);

    await Sql.upsertMediaMetadata(metadataFor(movie));
    await Sql.upsertMediaMetadata(
      metadataFor(movie, synopsis: 'Updated synopsis.', fetchedAt: 2000),
    );

    final metadata = await Sql.getMediaMetadata(movie.id!);

    expect(metadata?.synopsis, 'Updated synopsis.');
    expect(metadata?.year, '2026');
    expect(metadata?.rating, '8.4');
    expect(metadata?.durationSeconds, 5400);
    expect(metadata?.genres, ['Drama', 'Mystery']);
    expect(metadata?.cast, ['Actor One', 'Actor Two']);
    expect(metadata?.backdrop, 'https://example.com/backdrop.jpg');
    expect(metadata?.poster, 'https://example.com/poster.jpg');
    expect(metadata?.fetchedAt, 2000);
  });

  test('isMediaMetadataFresh respects the configured ttl', () async {
    await useTemporaryDatabase('freshness');
    final sourceId = await createSource();
    final movie = await createMovie(sourceId);
    await Sql.upsertMediaMetadata(metadataFor(movie, fetchedAt: 1000));

    expect(
      await Sql.isMediaMetadataFresh(
        movie.id!,
        now: DateTime.fromMillisecondsSinceEpoch(1000 * 1000, isUtc: true),
        ttl: const Duration(days: 7),
      ),
      isTrue,
    );
    expect(
      await Sql.isMediaMetadataFresh(
        movie.id!,
        now: DateTime.fromMillisecondsSinceEpoch(
          (1000 + 8 * 24 * 3600) * 1000,
          isUtc: true,
        ),
        ttl: const Duration(days: 7),
      ),
      isFalse,
    );
  });

  test('wipeSource deletes metadata rows for that source', () async {
    await useTemporaryDatabase('wipe');
    final sourceId = await createSource();
    final movie = await createMovie(sourceId);
    await Sql.upsertMediaMetadata(metadataFor(movie));

    await Sql.commitWrite([Sql.wipeSource(sourceId)]);

    expect(await Sql.getMediaMetadata(movie.id!), isNull);
  });
}
