import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topal_iptv/channel_widget_key.dart';
import 'package:topal_iptv/live_epg.dart';
import 'package:topal_iptv/models/channel.dart';
import 'package:topal_iptv/models/epg_program.dart';
import 'package:topal_iptv/models/media_type.dart';

Channel liveChannel() {
  return Channel(
    id: 4,
    name: 'News HD',
    mediaType: MediaType.livestream,
    sourceId: 1,
    favorite: false,
    streamId: 44,
    url: 'https://example.com/live/u/p/44.ts',
  );
}

EpgProgram program(String title, int start, int stop) {
  return EpgProgram(
    channelId: 4,
    sourceId: 1,
    streamId: 44,
    title: title,
    description: 'Description',
    startTimestamp: start,
    stopTimestamp: stop,
    fetchedAt: 1000,
  );
}

void main() {
  testWidgets('LiveEpgRow renders current and next programs', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveEpgRow(
            channel: liveChannel(),
            nowNext: EpgNowNext(
              current: program('Morning News', 1000, 1100),
              next: program('Weather', 1100, 1200),
            ),
            loading: false,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('News HD'), findsOneWidget);
    expect(find.text('Morning News'), findsOneWidget);
    expect(find.text('Next: Weather'), findsOneWidget);

    await tester.tap(find.text('Morning News'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('LiveEpgRow renders loading and missing EPG states', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              LiveEpgRow(
                channel: liveChannel(),
                nowNext: null,
                loading: true,
                onTap: () {},
              ),
              LiveEpgRow(
                channel: liveChannel(),
                nowNext: null,
                loading: false,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Loading EPG...'), findsOneWidget);
    expect(find.text('No EPG data'), findsOneWidget);
  });

  testWidgets('LiveEpgList renders loaded and unresolved row states', (
    tester,
  ) async {
    final channels = [
      liveChannel(),
      Channel(
        id: 5,
        name: 'Sports HD',
        mediaType: MediaType.livestream,
        sourceId: 1,
        favorite: false,
        streamId: 45,
        url: 'https://example.com/live/u/p/45.ts',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              LiveEpgList(
                channels: channels,
                nowNextByChannelId: const {},
                resolvedChannelIds: const {4},
                loading: true,
                onChannelTap: (_, _) {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('No EPG data'), findsOneWidget);
    expect(find.text('Loading EPG...'), findsOneWidget);
    expect(find.byKey(channelWidgetKey(channels.first)), findsOneWidget);
    expect(find.byKey(channelWidgetKey(channels.last)), findsOneWidget);
  });
}
