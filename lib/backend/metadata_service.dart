import 'package:topal_iptv/backend/sql.dart';
import 'package:topal_iptv/backend/xtream.dart';
import 'package:topal_iptv/models/channel.dart';
import 'package:topal_iptv/models/media_metadata.dart';
import 'package:topal_iptv/models/media_type.dart';

const Duration metadataCacheTtl = Duration(days: 7);

typedef MediaMetadataFetcher = Future<MediaMetadata?> Function(Channel channel);

Future<MediaMetadata?> loadMediaMetadata(
  Channel channel, {
  DateTime? now,
  Duration ttl = metadataCacheTtl,
  MediaMetadataFetcher? fetchMetadata,
}) async {
  final channelId = channel.id;
  if (channelId == null || !shouldLoadMetadata(channel)) return null;

  if (await Sql.isMediaMetadataFresh(channelId, now: now, ttl: ttl)) {
    return Sql.getMediaMetadata(channelId);
  }

  final fetcher = fetchMetadata ?? getXtreamMediaMetadata;
  try {
    final metadata = await fetcher(channel);
    if (metadata == null) return Sql.getMediaMetadata(channelId);
    await Sql.upsertMediaMetadata(metadata);
    return metadata;
  } catch (_) {
    return Sql.getMediaMetadata(channelId);
  }
}

bool shouldLoadMetadata(Channel channel) {
  if (channel.mediaType == MediaType.serie) return true;
  return channel.mediaType == MediaType.movie && channel.seriesId == null;
}
