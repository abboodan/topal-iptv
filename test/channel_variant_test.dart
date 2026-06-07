import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:topal_iptv/backend/db_factory.dart';
import 'package:topal_iptv/backend/sql.dart';
import 'package:topal_iptv/models/channel.dart';
import 'package:topal_iptv/models/filters.dart';
import 'package:topal_iptv/models/media_type.dart';
import 'package:topal_iptv/models/source.dart';
import 'package:topal_iptv/models/source_type.dart';
import 'package:topal_iptv/models/view_type.dart';

Channel liveVariant({
  required String name,
  required int streamId,
  int sourceId = -1,
  bool favorite = false,
  String? group,
}) {
  return Channel(
    name: name,
    group: group,
    mediaType: MediaType.livestream,
    sourceId: sourceId,
    favorite: favorite,
    streamId: streamId,
    url: 'https://example.com/live/$streamId.ts',
  );
}

Future<void> useTemporaryDatabase(String testName) async {
  final tempDir = await Directory.systemTemp.createTemp('topal_$testName');
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
        name: 'Test Source',
        sourceType: SourceType.xtream,
        url: 'https://example.com',
        username: 'u',
        password: 'p',
      ),
    ),
  ]);
  final source = (await Sql.getSources()).single;
  return source.id!;
}

void main() {
  test('channel variant keys distinguish stream and URL variants', () {
    expect(
      Sql.channelVariantKey(liveVariant(name: 'News HD', streamId: 10)),
      'live:10',
    );
    expect(
      Sql.channelVariantKey(
        Channel(
          name: 'Movie A',
          mediaType: MediaType.movie,
          sourceId: -1,
          favorite: false,
          streamId: 20,
          url: 'https://example.com/movie/20.mp4',
        ),
      ),
      'movie:20',
    );
    expect(
      Sql.channelVariantKey(
        Channel(
          name: 'Episode 1',
          mediaType: MediaType.movie,
          sourceId: -1,
          favorite: false,
          seriesId: 77,
          url: 'https://example.com/series/900.mp4',
        ),
      ),
      'episode:77:https://example.com/series/900.mp4',
    );
    expect(
      Sql.channelVariantKey(
        Channel(
          name: 'M3U News',
          mediaType: MediaType.livestream,
          sourceId: -1,
          favorite: false,
          url: 'https://cdn.example.com/news.m3u8',
        ),
      ),
      'url:0:https://cdn.example.com/news.m3u8',
    );
  });

  test('insertChannel keeps duplicate names when variants differ', () async {
    await useTemporaryDatabase('duplicate_variants');
    final sourceId = await createSource();

    await Sql.commitWrite([
      Sql.insertChannel(
        liveVariant(name: 'News HD', streamId: 101, sourceId: sourceId),
      ),
      Sql.insertChannel(
        liveVariant(name: 'News HD', streamId: 102, sourceId: sourceId),
      ),
    ]);

    final channels = await Sql.search(
      Filters(
        query: 'News HD',
        viewType: ViewType.all,
        mediaTypes: [MediaType.livestream],
        sourceIds: [sourceId],
      ),
    );

    expect(channels, hasLength(2));
    expect(
      channels.map((channel) => channel.streamId),
      containsAll([101, 102]),
    );
    expect(
      channels.map((channel) => channel.variantKey),
      containsAll(['live:101', 'live:102']),
    );
  });

  test(
    'preserve restores favorites and history to the matching variant',
    () async {
      await useTemporaryDatabase('variant_preserve');
      final sourceId = await createSource();

      await Sql.commitWrite([
        Sql.insertChannel(
          liveVariant(name: 'News HD', streamId: 101, sourceId: sourceId),
        ),
        Sql.insertChannel(
          liveVariant(name: 'News HD', streamId: 102, sourceId: sourceId),
        ),
      ]);
      final original = await Sql.search(
        Filters(
          query: 'News HD',
          viewType: ViewType.all,
          mediaTypes: [MediaType.livestream],
          sourceIds: [sourceId],
        ),
      );
      final selected = original.singleWhere(
        (channel) => channel.streamId == 102,
      );
      await Sql.favoriteChannel(selected.id!, true);
      await Sql.addToHistory(selected.id!);

      final preserve = await Sql.getChannelsPreserve(sourceId);
      await Sql.commitWrite([
        Sql.getOrCreateSourceByName(
          Source(
            name: 'Test Source',
            sourceType: SourceType.xtream,
            url: 'https://example.com',
            username: 'u',
            password: 'p',
          ),
        ),
        Sql.wipeSource(sourceId),
        Sql.insertChannel(
          liveVariant(name: 'News HD', streamId: 101, sourceId: sourceId),
        ),
        Sql.insertChannel(
          liveVariant(name: 'News HD', streamId: 102, sourceId: sourceId),
        ),
        Sql.restorePreserve(preserve),
      ]);

      final restored = await Sql.search(
        Filters(
          query: 'News HD',
          viewType: ViewType.all,
          mediaTypes: [MediaType.livestream],
          sourceIds: [sourceId],
        ),
      );
      final restoredSelected = restored.singleWhere(
        (channel) => channel.streamId == 102,
      );
      final other = restored.singleWhere((channel) => channel.streamId == 101);

      expect(restoredSelected.favorite, isTrue);
      expect(other.favorite, isFalse);

      final history = await Sql.search(
        Filters(
          viewType: ViewType.history,
          mediaTypes: [MediaType.livestream],
          sourceIds: [sourceId],
        ),
      );
      expect(history.single.streamId, 102);
    },
  );

  test('getChannelVariants returns only equivalent variant rows', () async {
    await useTemporaryDatabase('variant_query');
    final sourceId = await createSource();

    await Sql.commitWrite([
      Sql.insertChannel(
        liveVariant(name: 'News HD', streamId: 101, sourceId: sourceId),
      ),
      Sql.insertChannel(
        liveVariant(name: 'News HD', streamId: 102, sourceId: sourceId),
      ),
      Sql.insertChannel(
        liveVariant(name: 'Sports HD', streamId: 103, sourceId: sourceId),
      ),
    ]);

    final channels = await Sql.search(
      Filters(
        query: 'News HD',
        viewType: ViewType.all,
        mediaTypes: [MediaType.livestream],
        sourceIds: [sourceId],
      ),
    );
    final variants = await Sql.getChannelVariants(channels.first);

    expect(variants, hasLength(2));
    expect(variants.map((channel) => channel.name).toSet(), {'News HD'});
    expect(
      variants.map((channel) => channel.streamId),
      containsAll([101, 102]),
    );
  });

  test('updateGroups assigns group ids after variant upserts', () async {
    await useTemporaryDatabase('variant_groups');
    final sourceId = await createSource();

    await Sql.commitWrite([
      Sql.getOrCreateSourceByName(
        Source(
          name: 'Test Source',
          sourceType: SourceType.xtream,
          url: 'https://example.com',
          username: 'u',
          password: 'p',
        ),
      ),
      Sql.insertChannel(
        liveVariant(
          name: 'News HD',
          streamId: 101,
          sourceId: sourceId,
          group: 'News',
        ),
      ),
      Sql.updateGroups(),
    ]);

    final channels = await Sql.search(
      Filters(
        query: 'News HD',
        viewType: ViewType.all,
        mediaTypes: [MediaType.livestream],
        sourceIds: [sourceId],
      ),
    );

    expect(channels.single.groupId, isNotNull);
  });
}
