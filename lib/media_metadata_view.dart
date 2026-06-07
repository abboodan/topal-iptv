import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:topal_iptv/models/media_metadata.dart';

String formatMetadataDuration(int seconds) {
  final duration = Duration(seconds: seconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
  if (hours > 0) return '${hours}h';
  return '${duration.inMinutes}m';
}

class MetadataDetails extends StatelessWidget {
  final MediaMetadata? metadata;
  final bool includeDuration;

  const MetadataDetails({
    super.key,
    required this.metadata,
    this.includeDuration = true,
  });

  @override
  Widget build(BuildContext context) {
    final data = metadata;
    if (data == null || !data.hasDetails) return const SizedBox.shrink();

    final synopsis = data.synopsis?.trim();
    final cast = data.cast.join(', ');
    final chips = <Widget>[
      if (data.year?.trim().isNotEmpty == true) Chip(label: Text(data.year!)),
      if (data.rating?.trim().isNotEmpty == true)
        Chip(
          avatar: const Icon(Icons.star, size: 18, color: Colors.amber),
          label: Text(data.rating!),
        ),
      if (includeDuration && data.durationSeconds != null)
        Chip(label: Text(formatMetadataDuration(data.durationSeconds!))),
      for (final genre in data.genres) Chip(label: Text(genre)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chips.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: chips),
        if (synopsis != null && synopsis.isNotEmpty) ...[
          if (chips.isNotEmpty) const SizedBox(height: 14),
          Text(
            'Synopsis',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(synopsis, style: Theme.of(context).textTheme.bodyLarge),
        ],
        if (cast.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'Cast',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(cast, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class MetadataBackdrop extends StatelessWidget {
  final MediaMetadata? metadata;

  const MetadataBackdrop({super.key, required this.metadata});

  @override
  Widget build(BuildContext context) {
    final backdrop = metadata?.backdrop?.trim();
    if (backdrop == null || backdrop.isEmpty) return const SizedBox.shrink();

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: backdrop,
          fit: BoxFit.cover,
          memCacheWidth: 960,
          memCacheHeight: 540,
          errorWidget: (_, _, _) => DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
            ),
            child: const Center(child: Icon(Icons.image_not_supported)),
          ),
        ),
      ),
    );
  }
}
