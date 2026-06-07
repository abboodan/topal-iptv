import 'package:topal_iptv/models/channel.dart';

class LiveChannelContext {
  final List<Channel> channels;
  final int currentIndex;

  LiveChannelContext({
    required List<Channel> channels,
    required this.currentIndex,
  }) : channels = List.unmodifiable(channels) {
    if (channels.isEmpty) {
      throw ArgumentError.value(channels, 'channels', 'Cannot be empty');
    }
    if (currentIndex < 0 || currentIndex >= channels.length) {
      throw RangeError.index(currentIndex, channels, 'currentIndex');
    }
  }

  Channel get current => channels[currentIndex];

  String get positionLabel => '${currentIndex + 1} / ${channels.length}';

  bool get canGoPrevious => currentIndex > 0;

  bool get canGoNext => currentIndex < channels.length - 1;

  Channel? previous() => canGoPrevious ? channels[currentIndex - 1] : null;

  Channel? next() => canGoNext ? channels[currentIndex + 1] : null;

  LiveChannelContext? previousContext() =>
      canGoPrevious ? moveTo(currentIndex - 1) : null;

  LiveChannelContext? nextContext() =>
      canGoNext ? moveTo(currentIndex + 1) : null;

  LiveChannelContext moveTo(int index) {
    return LiveChannelContext(channels: channels, currentIndex: index);
  }
}
