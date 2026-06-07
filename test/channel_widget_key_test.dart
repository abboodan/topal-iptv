import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topal_iptv/channel_widget_key.dart';
import 'package:topal_iptv/models/channel.dart';
import 'package:topal_iptv/models/media_type.dart';

Channel channel({int? id, String? variantKey, String name = 'News HD'}) {
  return Channel(
    id: id,
    name: name,
    variantKey: variantKey,
    mediaType: MediaType.livestream,
    sourceId: 4,
    favorite: false,
    streamId: 50,
    url: 'https://example.com/live.ts',
  );
}

void main() {
  test('channelWidgetKey prefers database id for stability', () {
    expect(
      channelWidgetKey(channel(id: 10, variantKey: 'live:50')),
      const ValueKey<String>('channel-id:10'),
    );
  });

  test('channelWidgetKey falls back to variant identity', () {
    expect(
      channelWidgetKey(channel(variantKey: 'live:50')),
      const ValueKey<String>('channel-variant:4:live:50'),
    );
  });
}
