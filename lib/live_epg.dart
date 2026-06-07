import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:topal_iptv/channel_widget_key.dart';
import 'package:topal_iptv/models/channel.dart';
import 'package:topal_iptv/models/epg_program.dart';

typedef LiveEpgChannelTap = void Function(Channel channel, int index);

String formatEpgClock(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String formatEpgProgramRange(EpgProgram program) {
  return '${formatEpgClock(program.startTime)} - ${formatEpgClock(program.stopTime)}';
}

class LiveEpgList extends StatelessWidget {
  final List<Channel> channels;
  final Map<int, EpgNowNext> nowNextByChannelId;
  final Set<int> resolvedChannelIds;
  final bool loading;
  final LiveEpgChannelTap onChannelTap;

  const LiveEpgList({
    super.key,
    required this.channels,
    required this.nowNextByChannelId,
    required this.resolvedChannelIds,
    required this.loading,
    required this.onChannelTap,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 10),
      sliver: SliverList.builder(
        itemCount: channels.length,
        itemBuilder: (context, index) {
          final channel = channels[index];
          final channelId = channel.id;
          return LiveEpgRow(
            key: channelWidgetKey(channel),
            channel: channel,
            nowNext: channelId == null ? null : nowNextByChannelId[channelId],
            loading:
                loading &&
                channelId != null &&
                !resolvedChannelIds.contains(channelId),
            onTap: () => onChannelTap(channel, index),
          );
        },
      ),
    );
  }
}

class LiveEpgRow extends StatelessWidget {
  final Channel channel;
  final EpgNowNext? nowNext;
  final bool loading;
  final VoidCallback onTap;

  const LiveEpgRow({
    super.key,
    required this.channel,
    required this.nowNext,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final current = nowNext?.current;
    final next = nowNext?.next;
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        minLeadingWidth: 56,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: SizedBox.square(dimension: 56, child: channelLogo(context)),
        title: Text(
          channel.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (loading)
                const Text('Loading EPG...')
              else if (current == null)
                Text(
                  'No EPG data',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                )
              else ...[
                Text(
                  current.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  formatEpgProgramRange(current),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
              if (!loading && next != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Next: ${next.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ],
          ),
        ),
        trailing: const Icon(Icons.play_arrow),
        onTap: onTap,
      ),
    );
  }

  Widget channelLogo(BuildContext context) {
    final fallback = Icon(
      Icons.live_tv,
      color: Theme.of(context).colorScheme.primary,
    );
    final image = channel.image;
    if (image == null || image.trim().isEmpty) return Center(child: fallback);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: CachedNetworkImage(
        imageUrl: image,
        fit: BoxFit.contain,
        memCacheHeight: 160,
        memCacheWidth: 160,
        errorWidget: (_, _, _) => Center(child: fallback),
      ),
    );
  }
}
