import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:topal_iptv/backend/db_factory.dart';
import 'package:topal_iptv/backend/epg_service.dart';
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

Future<List<Channel>> createLiveChannels(int sourceId, int count) async {
  await Sql.commitWrite([
    for (var i = 0; i < count; i++)
      Sql.insertChannel(
        Channel(
          name: 'Channel $i',
          mediaType: MediaType.livestream,
          sourceId: sourceId,
          favorite: false,
          streamId: 700 + i,
          url: 'https://example.com/live/u/p/${700 + i}.ts',
        ),
      ),
  ]);
  return Sql.search(
    Filters(
      query: 'Channel',
      viewType: ViewType.all,
      mediaTypes: [MediaType.livestream],
      sourceIds: [sourceId],
    ),
  );
}

EpgProgram programFor(Channel channel, int fetchedAt) {
  return EpgProgram(
    channelId: channel.id!,
    sourceId: channel.sourceId,
    streamId: channel.streamId!,
    title: 'Program ${channel.streamId}',
    startTimestamp: 1000,
    stopTimestamp: 1100,
    fetchedAt: fetchedAt,
  );
}

void main() {
  test('refreshEpgForChannels skips fresh cache entries', () async {
    await useTemporaryDatabase('fresh_skip');
    final sourceId = await createSource();
    final channel = (await createLiveChannels(sourceId, 1)).single;
    await Sql.replaceEpgPrograms(channel.id!, [programFor(channel, 1000)]);

    var fetchCalls = 0;
    await refreshEpgForChannels(
      [channel],
      now: DateTime.fromMillisecondsSinceEpoch(1000 * 1000, isUtc: true),
      fetchPrograms: (channel) async {
        fetchCalls++;
        return [programFor(channel, 1000)];
      },
    );

    expect(fetchCalls, 0);
  });

  test('refreshEpgForChannels limits concurrent fetches', () async {
    await useTemporaryDatabase('bounded');
    final sourceId = await createSource();
    final channels = await createLiveChannels(sourceId, 5);
    var inFlight = 0;
    var maxInFlight = 0;

    await refreshEpgForChannels(
      channels,
      maxConcurrent: 2,
      now: DateTime.fromMillisecondsSinceEpoch(1000 * 1000, isUtc: true),
      fetchPrograms: (channel) async {
        inFlight++;
        if (inFlight > maxInFlight) maxInFlight = inFlight;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        inFlight--;
        return [programFor(channel, 1000)];
      },
    );

    expect(maxInFlight, lessThanOrEqualTo(2));
    final nowNext = await Sql.getNowNextEpgForChannels(
      channels,
      now: DateTime.fromMillisecondsSinceEpoch(1050 * 1000, isUtc: true),
    );
    expect(nowNext.values.where((entry) => entry.current != null), hasLength(5));
  });
}
