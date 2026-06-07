import 'package:flutter_test/flutter_test.dart';
import 'package:topal_iptv/models/channel.dart';
import 'package:topal_iptv/models/media_type.dart';
import 'package:topal_iptv/player_controls/live_channel_context.dart';

void main() {
  Channel live(int id, String name) {
    return Channel(
      id: id,
      name: name,
      mediaType: MediaType.livestream,
      sourceId: 1,
      url: 'http://example.com/$id',
      favorite: false,
    );
  }

  test('live channel context exposes current position and neighbors', () {
    final channels = [live(1, 'One'), live(2, 'Two'), live(3, 'Three')];
    final context = LiveChannelContext(channels: channels, currentIndex: 1);

    expect(context.current.name, 'Two');
    expect(context.positionLabel, '2 / 3');
    expect(context.canGoPrevious, isTrue);
    expect(context.canGoNext, isTrue);
    expect(context.previous()?.name, 'One');
    expect(context.next()?.name, 'Three');
  });

  test('live channel context clamps edges without wrapping', () {
    final channels = [live(1, 'One'), live(2, 'Two')];

    final first = LiveChannelContext(channels: channels, currentIndex: 0);
    final last = LiveChannelContext(channels: channels, currentIndex: 1);

    expect(first.canGoPrevious, isFalse);
    expect(first.previous(), isNull);
    expect(first.next()?.name, 'Two');
    expect(last.canGoNext, isFalse);
    expect(last.next(), isNull);
    expect(last.previous()?.name, 'One');
  });

  test('live channel context can move to another index', () {
    final channels = [live(1, 'One'), live(2, 'Two'), live(3, 'Three')];
    final context = LiveChannelContext(channels: channels, currentIndex: 0);

    expect(context.moveTo(2).current.name, 'Three');
  });
}
