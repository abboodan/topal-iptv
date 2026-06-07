import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topal_iptv/movie_detail.dart';
import 'package:topal_iptv/models/channel.dart';
import 'package:topal_iptv/models/media_metadata.dart';
import 'package:topal_iptv/models/media_type.dart';

Channel buildMovie({String? image}) {
  return Channel(
    id: 7,
    name: 'Example Movie',
    group: 'Arabic Movies',
    image: image,
    mediaType: MediaType.movie,
    sourceId: 1,
    favorite: false,
  );
}

void main() {
  test('formats resume positions for display', () {
    expect(formatResumePosition(65), '1:05');
    expect(formatResumePosition(3661), '1:01:01');
  });

  testWidgets('movie detail body shows play action without resume', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MovieDetailBody(
            channel: buildMovie(),
            resumeSeconds: null,
            isFavorite: false,
            onPlay: () {},
            onStartOver: () {},
            onToggleFavorite: () {},
          ),
        ),
      ),
    );

    expect(find.text('Example Movie'), findsOneWidget);
    expect(find.text('Arabic Movies'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Start over'), findsNothing);
  });

  testWidgets('compact movie detail body does not duplicate poster image', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 800,
            child: MovieDetailBody(
              channel: buildMovie(image: 'https://example.com/poster.jpg'),
              resumeSeconds: null,
              isFavorite: false,
              onPlay: () {},
              onStartOver: () {},
              onToggleFavorite: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets('movie detail body shows resume and start over actions', (
    tester,
  ) async {
    var played = false;
    var startedOver = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MovieDetailBody(
            channel: buildMovie(),
            resumeSeconds: 125,
            isFavorite: true,
            onPlay: () => played = true,
            onStartOver: () => startedOver = true,
            onToggleFavorite: () {},
          ),
        ),
      ),
    );

    expect(find.text('Resume 2:05'), findsOneWidget);
    expect(find.text('Start over'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsOneWidget);

    await tester.tap(find.text('Resume 2:05'));
    await tester.pump();
    await tester.tap(find.text('Start over'));
    await tester.pump();

    expect(played, isTrue);
    expect(startedOver, isTrue);
  });

  testWidgets('movie detail body renders provider metadata when present', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 900,
            child: MovieDetailBody(
              channel: buildMovie(),
              metadata: const MediaMetadata(
                channelId: 7,
                sourceId: 1,
                synopsis: 'Sue is back on the dating scene.',
                year: '2023',
                rating: '7.2',
                durationSeconds: 5940,
                genres: ['Comedy', 'Drama'],
                cast: ['Maggie ONeill', 'Tony Pitts'],
                fetchedAt: 1000,
              ),
              resumeSeconds: null,
              isFavorite: false,
              onPlay: () {},
              onStartOver: () {},
              onToggleFavorite: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Sue is back on the dating scene.'), findsOneWidget);
    expect(find.text('2023'), findsOneWidget);
    expect(find.text('7.2'), findsOneWidget);
    expect(find.text('1h 39m'), findsOneWidget);
    expect(find.text('Comedy'), findsOneWidget);
    expect(find.text('Drama'), findsOneWidget);
    expect(find.text('Maggie ONeill, Tony Pitts'), findsOneWidget);
  });

  testWidgets('wide movie detail keeps play action before metadata', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 900,
            child: MovieDetailBody(
              channel: buildMovie(),
              metadata: const MediaMetadata(
                channelId: 7,
                sourceId: 1,
                synopsis: 'A long provider synopsis.',
                fetchedAt: 1000,
              ),
              resumeSeconds: null,
              isFavorite: false,
              onPlay: () {},
              onStartOver: () {},
              onToggleFavorite: () {},
            ),
          ),
        ),
      ),
    );

    final playTop = tester.getTopLeft(find.text('Play')).dy;
    final synopsisTop = tester.getTopLeft(find.text('Synopsis')).dy;

    expect(playTop, lessThan(synopsisTop));
  });
}
