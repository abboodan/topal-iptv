import 'package:flutter/foundation.dart';
import 'package:topal_iptv/models/channel.dart';

Key channelWidgetKey(Channel channel) {
  final id = channel.id;
  if (id != null) return ValueKey<String>('channel-id:$id');

  final variantKey = channel.variantKey;
  if (variantKey != null && variantKey.trim().isNotEmpty) {
    return ValueKey<String>('channel-variant:${channel.sourceId}:$variantKey');
  }

  return ValueKey<String>(
    'channel-fallback:${channel.sourceId}:${channel.mediaType.index}:${channel.url ?? channel.name}',
  );
}
