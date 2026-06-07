import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:topal_iptv/backend/db_factory.dart';
import 'package:topal_iptv/backend/sql.dart';
import 'package:topal_iptv/models/channel.dart';
import 'package:topal_iptv/models/epg_program.dart';
import 'package:topal_iptv/models/filters.dart';
import 'package:topal_iptv/models/media_type.dart';
import 'package:topal_iptv/models/source.dart';
import 'package:topal_iptv/models/source_type.dart';
import 'package:topal_iptv/models/view_type.dart';

Future<void> useTemporaryDatabase(String testName) async {
  final tempDir = await Directory.systemTemp.createTemp('topal_epg_$testName');
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
        name: 'EPG Source',
        sourceType: SourceType.xtream,
        url: 'https://example.com/player_api.php',
        username: 'u',
        password: 'p',
      ),
    ),
  ]);
  return (await Sql.getSources()).single.id!;
}

Future<Channel> createLiveChannel({
  required int sourceId,
  required int streamId,
}) async {
  await Sql.commitWrite([
    Sql.insertChannel(
      Channel(
        name: 'News HD',
        mediaType: MediaType.livestream,
        sourceId: sourceId,
        favorite: false,
        streamId: streamId,
        url: 'https://example.com/live/u/p/$streamId.ts',
      ),
    ),
  ]);
  return (await Sql.search(
    Filters(
      query: 'News HD',
      viewType: ViewType.all,
      mediaTypes: [MediaType.livestream],
      sourceIds: [sourceId],
    ),
  )).single;
}

EpgProgram program({
  required Channel channel,
  required String title,
  required int start,
  required int stop,
  int fetchedAt = 1000,
}) {
  return EpgProgram(
    channelId: channel.id!,
    sourceId: channel.sourceId,
    streamId: channel.streamId!,
    title: title,
    description: 'About $title',
    startTimestamp: start,
    stopTimestamp: stop,
    fetchedAt: fetchedAt,
  );
}

void main() {
  test('replaceEpgPrograms queries current and next programs', () async {
    await useTemporaryDatabase('now_next');
    final sourceId = await createSource();
    final channel = await createLiveChannel(sourceId: sourceId, streamId: 501);

    await Sql.replaceEpgPrograms(channel.id!, [
      program(channel: channel, title: 'Morning News', start: 1000, stop: 1100),
      program(channel: channel, title: 'Weather', start: 1100, stop: 1200),
    ]);

    final nowNext = await Sql.getNowNextEpgForChannels([
      channel,
    ], now: DateTime.fromMillisecondsSinceEpoch(1050 * 1000, isUtc: true));

    expect(nowNext[channel.id!]?.current?.title, 'Morning News');
    expect(nowNext[channel.id!]?.next?.title, 'Weather');
  });

  test('replaceEpgPrograms clears stale rows for a channel', () async {
    await useTemporaryDatabase('replace');
    final sourceId = await createSource();
    final channel = await createLiveChannel(sourceId: sourceId, streamId: 502);

    await Sql.replaceEpgPrograms(channel.id!, [
      program(channel: channel, title: 'Old Program', start: 1000, stop: 1100),
    ]);
    await Sql.replaceEpgPrograms(channel.id!, [
      program(channel: channel, title: 'New Program', start: 1000, stop: 1100),
    ]);

    final nowNext = await Sql.getNowNextEpgForChannels([
      channel,
    ], now: DateTime.fromMillisecondsSinceEpoch(1050 * 1000, isUtc: true));

    expect(nowNext[channel.id!]?.current?.title, 'New Program');
    expect(nowNext[channel.id!]?.next, isNull);
  });

  test('isEpgCacheFresh respects the configured ttl', () async {
    await useTemporaryDatabase('freshness');
    final sourceId = await createSource();
    final channel = await createLiveChannel(sourceId: sourceId, streamId: 503);

    await Sql.replaceEpgPrograms(channel.id!, [
      program(
        channel: channel,
        title: 'Cached Program',
        start: 1000,
        stop: 1100,
        fetchedAt: 1000,
      ),
    ]);

    expect(
      await Sql.isEpgCacheFresh(
        channel.id!,
        now: DateTime.fromMillisecondsSinceEpoch(1000 * 1000, isUtc: true),
        ttl: const Duration(hours: 6),
      ),
      isTrue,
    );
    expect(
      await Sql.isEpgCacheFresh(
        channel.id!,
        now: DateTime.fromMillisecondsSinceEpoch(
          (1000 + 7 * 3600) * 1000,
          isUtc: true,
        ),
        ttl: const Duration(hours: 6),
      ),
      isFalse,
    );
  });

  test('replaceEpgPrograms records fresh cache even with no rows', () async {
    await useTemporaryDatabase('empty_cache');
    final sourceId = await createSource();
    final channel = await createLiveChannel(sourceId: sourceId, streamId: 505);

    await Sql.replaceEpgPrograms(
      channel.id!,
      [],
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(1000 * 1000, isUtc: true),
    );

    expect(
      await Sql.isEpgCacheFresh(
        channel.id!,
        now: DateTime.fromMillisecondsSinceEpoch(1001 * 1000, isUtc: true),
      ),
      isTrue,
    );

    final nowNext = await Sql.getNowNextEpgForChannels([
      channel,
    ], now: DateTime.fromMillisecondsSinceEpoch(1001 * 1000, isUtc: true));

    expect(nowNext[channel.id!]?.current, isNull);
  });

  test('wipeSource deletes EPG rows for that source', () async {
    await useTemporaryDatabase('wipe');
    final sourceId = await createSource();
    final channel = await createLiveChannel(sourceId: sourceId, streamId: 504);

    await Sql.replaceEpgPrograms(channel.id!, [
      program(channel: channel, title: 'Program', start: 1000, stop: 1100),
    ]);
    await Sql.commitWrite([Sql.wipeSource(sourceId)]);

    final nowNext = await Sql.getNowNextEpgForChannels([
      channel,
    ], now: DateTime.fromMillisecondsSinceEpoch(1050 * 1000, isUtc: true));

    expect(nowNext[channel.id!]?.current, isNull);
  });
}
