import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:topal_iptv/backend/xtream.dart';
import 'package:topal_iptv/models/channel.dart';
import 'package:topal_iptv/models/media_type.dart';
import 'package:topal_iptv/models/source.dart';
import 'package:topal_iptv/models/source_type.dart';
import 'package:topal_iptv/models/xtream_types.dart';

String encoded(String value) => base64Encode(utf8.encode(value));

Channel liveChannel() {
  return Channel(
    id: 44,
    name: 'News HD',
    mediaType: MediaType.livestream,
    sourceId: 2,
    favorite: false,
    streamId: 501,
    url: 'https://example.com/live/u/p/501.ts',
  );
}

void main() {
  test('decodeXtreamEpgText accepts base64 and plain text', () {
    expect(decodeXtreamEpgText(encoded('Morning News')), 'Morning News');
    expect(decodeXtreamEpgText('Plain title'), 'Plain title');
    expect(decodeXtreamEpgText(null), '');
  });

  test('xtreamEpgToPrograms decodes valid listings and ignores invalid times', () {
    final programs = xtreamEpgToPrograms(
      XtreamEPG.fromJson({
        'epg_listings': [
          {
            'id': '1',
            'title': encoded('Morning News'),
            'description': encoded('Latest headlines'),
            'start_timestamp': '1000',
            'stop_timestamp': '1100',
          },
          {
            'id': '2',
            'title': 'Broken time',
            'start_timestamp': 'bad',
            'stop_timestamp': '1200',
          },
        ],
      }),
      liveChannel(),
      fetchedAt: 999,
    );

    expect(programs, hasLength(1));
    expect(programs.single.title, 'Morning News');
    expect(programs.single.description, 'Latest headlines');
    expect(programs.single.channelId, 44);
    expect(programs.single.sourceId, 2);
    expect(programs.single.streamId, 501);
    expect(programs.single.fetchedAt, 999);
  });

  test('buildXtreamUrl supports get_short_epg stream queries', () {
    final url = buildXtreamUrl(
      Source(
        name: 'Test',
        sourceType: SourceType.xtream,
        url: 'https://example.com/player_api.php',
        username: 'user',
        password: 'pass',
      ),
      getShortEpg,
      {'stream_id': '501', 'limit': '4'},
    );

    expect(url.queryParameters['action'], getShortEpg);
    expect(url.queryParameters['stream_id'], '501');
    expect(url.queryParameters['limit'], '4');
  });
}
