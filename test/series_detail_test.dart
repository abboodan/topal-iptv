import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topal_iptv/models/channel.dart';
import 'package:topal_iptv/models/media_metadata.dart';
import 'package:topal_iptv/models/media_type.dart';
import 'package:topal_iptv/series_detail.dart';

Channel buildSeries() {
  return Channel(
    id: 10,
    name: 'Example Series',
    group: 'Drama',
    image: 'https://example.com/series.jpg',
    url: '12345',
    mediaType: MediaType.serie,
    sourceId: 1,
    favorite: false,
  );
}

Channel buildEpisode(String name) {
  return Channel(
    id: name.hashCode,
    name: name,
    image: 'https://example.com/episode.jpg',
    url: 'https://example.com/$name.mp4',
    mediaType: MediaType.movie,
    sourceId: 1,
    favorite: false,
    seriesId: 12345,
  );
}

void main() {
  test('groups episodes by inferred season label', () {
    final groups = groupEpisodesBySeason([
      buildEpisode('Show S01 E01'),
      buildEpisode('Show S01 E02'),
      buildEpisode('Show S02 E01'),
    ]);

    expect(groups, hasLength(2));
    expect(groups[0].label, 'Season 1');
    expect(groups[0].episodes, hasLength(2));
    expect(groups[1].label, 'Season 2');
  });

  test(
    'falls back to a single episodes group when season cannot be inferred',
    () {
      final groups = groupEpisodesBySeason([
        buildEpisode('Pilot'),
        buildEpisode('Finale'),
      ]);

      expect(groups, hasLength(1));
      expect(groups.single.label, 'Episodes');
      expect(groups.single.episodes, hasLength(2));
    },
  );

  testWidgets('series detail body renders episodes and handles selection', (
    tester,
  ) async {
    Channel? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SeriesDetailBody(
            series: buildSeries(),
            episodes: [
              buildEpisode('Example Series S01 E01'),
              buildEpisode('Example Series S01 E02'),
            ],
            loading: false,
            error: null,
            onRetry: () {},
            onEpisodeSelected: (episode) => selected = episode,
          ),
        ),
      ),
    );

    expect(find.text('Example Series'), findsOneWidget);
    expect(find.text('Series'), findsOneWidget);
    expect(find.text('Drama'), findsOneWidget);
    expect(find.text('Season 1'), findsOneWidget);
    expect(find.text('Example Series S01 E01'), findsOneWidget);

    await tester.tap(find.text('Example Series S01 E01'));
    await tester.pump();

    expect(selected?.name, 'Example Series S01 E01');
  });

  testWidgets('series detail body renders provider metadata when present', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SeriesDetailBody(
            series: buildSeries(),
            metadata: const MediaMetadata(
              channelId: 10,
              sourceId: 1,
              synopsis: 'A premium series synopsis.',
              year: '2024',
              rating: '8.1',
              genres: ['Action', 'Thriller'],
              cast: ['Actor One', 'Actor Two'],
              fetchedAt: 1000,
            ),
            episodes: [buildEpisode('Example Series S01 E01')],
            loading: false,
            error: null,
            onRetry: () {},
            onEpisodeSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('A premium series synopsis.'), findsOneWidget);
    expect(find.text('2024'), findsOneWidget);
    expect(find.text('8.1'), findsOneWidget);
    expect(find.text('Action'), findsOneWidget);
    expect(find.text('Thriller'), findsOneWidget);
    expect(find.text('Actor One, Actor Two'), findsOneWidget);
  });
}
