import 'package:flutter/material.dart';
import 'package:topal_iptv/backend/sql.dart';
import 'package:topal_iptv/models/channel.dart';

String variantLabelFor(Channel channel) {
  final streamId = channel.streamId;
  if (streamId != null && streamId >= 0) return 'Stream $streamId';

  final url = channel.url;
  if (url != null && url.trim().isNotEmpty) {
    final uri = Uri.tryParse(url);
    final segment = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : null;
    if (segment != null && segment.trim().isNotEmpty) return segment;
  }

  return channel.variantKey ?? channel.name;
}

Future<Channel?> chooseChannelVariant(
  BuildContext context,
  Channel channel,
) async {
  final variants = await Sql.getChannelVariants(channel);
  if (variants.length <= 1) return channel;
  if (!context.mounted) return null;

  return showModalBottomSheet<Channel>(
    context: context,
    showDragHandle: true,
    builder: (context) => ChannelVariantPicker(
      variants: variants,
      currentVariantKey: channel.variantKey,
      onSelected: (variant) => Navigator.of(context).pop(variant),
    ),
  );
}

class ChannelVariantPicker extends StatelessWidget {
  final List<Channel> variants;
  final String? currentVariantKey;
  final ValueChanged<Channel> onSelected;

  const ChannelVariantPicker({
    super.key,
    required this.variants,
    required this.currentVariantKey,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choose version',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: variants.length,
                itemBuilder: (context, index) {
                  final variant = variants[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.play_circle_outline),
                    title: Text(variantLabelFor(variant)),
                    subtitle: Text(
                      variant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (variant.favorite)
                          const Icon(Icons.star, color: Colors.amber),
                        if (variant.variantKey == currentVariantKey) ...[
                          if (variant.favorite) const SizedBox(width: 8),
                          const Chip(label: Text('Current')),
                        ],
                      ],
                    ),
                    onTap: () => onSelected(variant),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
