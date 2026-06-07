import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topal_iptv/channel_variant_picker.dart';
import 'package:topal_iptv/models/channel.dart';
import 'package:topal_iptv/models/media_type.dart';

Channel buildVariant(int streamId) {
  return Channel(
    id: streamId,
    name: 'News HD',
    mediaType: MediaType.livestream,
    sourceId: 1,
    favorite: streamId == 102,
    streamId: streamId,
    url: 'https://example.com/live/$streamId.ts',
    variantKey: 'live:$streamId',
  );
}

void main() {
  test('variantLabelFor prefers stable stream identifiers', () {
    expect(variantLabelFor(buildVariant(101)), 'Stream 101');
  });

  testWidgets('channel variant picker displays variants and selects one', (
    tester,
  ) async {
    Channel? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChannelVariantPicker(
            variants: [buildVariant(101), buildVariant(102)],
            currentVariantKey: 'live:101',
            onSelected: (channel) => selected = channel,
          ),
        ),
      ),
    );

    expect(find.text('Choose version'), findsOneWidget);
    expect(find.text('Stream 101'), findsOneWidget);
    expect(find.text('Stream 102'), findsOneWidget);
    expect(find.text('Current'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsOneWidget);

    await tester.tap(find.text('Stream 102'));
    await tester.pump();

    expect(selected?.streamId, 102);
  });
}
