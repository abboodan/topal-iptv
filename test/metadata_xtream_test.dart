import 'package:flutter_test/flutter_test.dart';
import 'package:topal_iptv/backend/xtream.dart';
import 'package:topal_iptv/models/channel.dart';
import 'package:topal_iptv/models/media_type.dart';
import 'package:topal_iptv/models/source.dart';
import 'package:topal_iptv/models/source_type.dart';

Channel movieChannel() {
  return Channel(
    id: 11,
    name: 'Sweet Sue',
    mediaType: MediaType.movie,
    sourceId: 2,
    favorite: false,
    streamId: 501,
    url: 'https://example.com/movie/u/p/501.mp4',
  );
}

Channel seriesChannel() {
  return Channel(
    id: 12,
    name: 'Example Series',
    mediaType: MediaType.serie,
    sourceId: 2,
    favorite: false,
    url: '901',
  );
}

void main() {
  test('xtreamVodInfoToMetadata parses mixed provider fields', () {
    final metadata = xtreamVodInfoToMetadata(
      {
        'info': {
          'plot': 'Sue is back on the dating scene.',
          'releaseDate': '2023-03-10',
          'duration_secs': '5940',
          'rating': '7.2',
          'genre': 'Comedy / Drama, Romance',
          'cast': 'Maggie ONeill, Tony Pitts',
          'backdrop_path': ['https://example.com/backdrop.jpg'],
          'movie_image': 'https://example.com/poster.jpg',
        },
      },
      movieChannel(),
      fetchedAt: 1234,
    );

    expect(metadata?.synopsis, 'Sue is back on the dating scene.');
    expect(metadata?.year, '2023');
    expect(metadata?.durationSeconds, 5940);
    expect(metadata?.rating, '7.2');
    expect(metadata?.genres, ['Comedy', 'Drama', 'Romance']);
    expect(metadata?.cast, ['Maggie ONeill', 'Tony Pitts']);
    expect(metadata?.backdrop, 'https://example.com/backdrop.jpg');
    expect(metadata?.poster, 'https://example.com/poster.jpg');
    expect(metadata?.fetchedAt, 1234);
  });

  test('xtreamSeriesInfoToMetadata parses series info', () {
    final metadata = xtreamSeriesInfoToMetadata(
      {
        'info': {
          'description': 'A show synopsis.',
          'releasedate': '2024',
          'rating': 8.1,
          'genre': 'Action | Thriller',
          'actors': 'Actor One / Actor Two',
          'backdrop_path': 'https://example.com/series-backdrop.jpg',
          'cover': 'https://example.com/series-cover.jpg',
        },
      },
      seriesChannel(),
      fetchedAt: 5678,
    );

    expect(metadata?.synopsis, 'A show synopsis.');
    expect(metadata?.year, '2024');
    expect(metadata?.rating, '8.1');
    expect(metadata?.genres, ['Action', 'Thriller']);
    expect(metadata?.cast, ['Actor One', 'Actor Two']);
    expect(metadata?.backdrop, 'https://example.com/series-backdrop.jpg');
    expect(metadata?.poster, 'https://example.com/series-cover.jpg');
  });

  test('buildXtreamUrl supports get_vod_info stream queries', () {
    final url = buildXtreamUrl(
      Source(
        name: 'Test',
        sourceType: SourceType.xtream,
        url: 'https://example.com/player_api.php',
        username: 'user',
        password: 'pass',
      ),
      getVodInfo,
      {'vod_id': '501'},
    );

    expect(url.queryParameters['action'], getVodInfo);
    expect(url.queryParameters['vod_id'], '501');
  });
}
