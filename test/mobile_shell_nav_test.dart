import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topal_iptv/channel_tile.dart';
import 'package:topal_iptv/mobile_shell_nav.dart';
import 'package:topal_iptv/models/channel.dart';
import 'package:topal_iptv/models/media_type.dart';
import 'package:topal_iptv/models/mobile_section.dart';

void main() {
  test('mobile sections map to the intended media types', () {
    expect(MobileSection.live.mediaType, MediaType.livestream);
    expect(MobileSection.movies.mediaType, MediaType.movie);
    expect(MobileSection.series.mediaType, MediaType.serie);
  });

  testWidgets('mobile shell navigation exposes media-first destinations', (
    tester,
  ) async {
    final selected = <MobileSection>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: MobileShellNav(
            selectedSection: MobileSection.live,
            onSectionSelected: selected.add,
            onSettingsSelected: () => selected.add(MobileSection.settings),
          ),
        ),
      ),
    );

    expect(find.text('Live'), findsOneWidget);
    expect(find.text('Movies'), findsOneWidget);
    expect(find.text('Series'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.text('Movies'));
    await tester.pumpAndSettle();

    expect(selected, [MobileSection.movies]);
  });

  testWidgets('channel tile can show a media type label for global search', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ChannelTile(
                channel: Channel(
                  id: 1,
                  name: 'Example Movie',
                  mediaType: MediaType.movie,
                  sourceId: 1,
                  favorite: false,
                ),
                parentContext: context,
                setNode: (_) {},
                showMediaTypeLabel: true,
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('Movie'), findsOneWidget);
  });
}
