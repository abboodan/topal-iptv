import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:topal_iptv/backend/metadata_service.dart';
import 'package:topal_iptv/backend/settings_service.dart';
import 'package:topal_iptv/backend/sql.dart';
import 'package:topal_iptv/channel_variant_picker.dart';
import 'package:topal_iptv/error.dart';
import 'package:topal_iptv/media_metadata_view.dart';
import 'package:topal_iptv/models/channel.dart';
import 'package:topal_iptv/models/media_metadata.dart';
import 'package:topal_iptv/player.dart';

String formatResumePosition(int seconds) {
  final duration = Duration(seconds: seconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final remainingSeconds = duration.inSeconds.remainder(60);
  final secondText = remainingSeconds.toString().padLeft(2, '0');
  if (hours > 0) {
    final minuteText = minutes.toString().padLeft(2, '0');
    return '$hours:$minuteText:$secondText';
  }
  return '${duration.inMinutes}:$secondText';
}

class MovieDetailPage extends StatefulWidget {
  final Channel channel;

  const MovieDetailPage({super.key, required this.channel});

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  int? resumeSeconds;
  MediaMetadata? metadata;
  late bool isFavorite;

  @override
  void initState() {
    super.initState();
    isFavorite = widget.channel.favorite;
    loadResumePosition();
    unawaited(loadMetadata());
  }

  Future<void> loadResumePosition() async {
    final id = widget.channel.id;
    if (id == null) return;
    final position = await Sql.getPosition(id);
    if (!mounted) return;
    setState(() {
      resumeSeconds = position != null && position > 0 ? position : null;
    });
  }

  Future<void> loadMetadata() async {
    final loadedMetadata = await loadMediaMetadata(widget.channel);
    if (!mounted) return;
    setState(() => metadata = loadedMetadata);
  }

  Future<void> play({bool startOver = false}) async {
    await Error.tryAsyncNoLoading(() async {
      final selectedChannel = await chooseChannelVariant(
        context,
        widget.channel,
      );
      if (!mounted || selectedChannel == null) return;

      final id = selectedChannel.id;
      if (startOver && id != null) {
        await Sql.setPosition(id, 0);
        if (!mounted) return;
        setState(() => resumeSeconds = null);
      }

      final settings = await SettingsService.getSettings();
      if (id != null) await Sql.addToHistory(id);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Player(channel: selectedChannel, settings: settings),
        ),
      );
      if (!mounted) return;
      await loadResumePosition();
    }, context);
  }

  Future<void> toggleFavorite() async {
    final id = widget.channel.id;
    if (id == null) return;
    await Error.tryAsyncNoLoading(() async {
      final nextValue = !isFavorite;
      await Sql.favoriteChannel(id, nextValue);
      if (!mounted) return;
      setState(() {
        isFavorite = nextValue;
        widget.channel.favorite = nextValue;
      });
    }, context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.channel.name)),
      body: SafeArea(
        child: MovieDetailBody(
          channel: widget.channel,
          metadata: metadata,
          resumeSeconds: resumeSeconds,
          isFavorite: isFavorite,
          onPlay: play,
          onStartOver: () => play(startOver: true),
          onToggleFavorite: toggleFavorite,
        ),
      ),
    );
  }
}

class MovieDetailBody extends StatelessWidget {
  final Channel channel;
  final MediaMetadata? metadata;
  final int? resumeSeconds;
  final bool isFavorite;
  final VoidCallback onPlay;
  final VoidCallback onStartOver;
  final VoidCallback onToggleFavorite;

  const MovieDetailBody({
    super.key,
    required this.channel,
    this.metadata,
    required this.resumeSeconds,
    required this.isFavorite,
    required this.onPlay,
    required this.onStartOver,
    required this.onToggleFavorite,
  });

  bool get hasResume => resumeSeconds != null && resumeSeconds! > 0;

  String get actionLabel {
    if (!hasResume) return 'Play';
    return 'Resume ${formatResumePosition(resumeSeconds!)}';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final content = wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 300, child: poster(context)),
                  const SizedBox(width: 28),
                  Expanded(child: details(context, compact: false)),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 132, child: poster(context)),
                      const SizedBox(width: 16),
                      Expanded(child: details(context, compact: true)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  actions(context),
                  const SizedBox(height: 20),
                  MetadataDetails(metadata: metadata),
                  if (metadata?.backdrop?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 18),
                    MetadataBackdrop(metadata: metadata),
                  ],
                ],
              );

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: content,
        );
      },
    );
  }

  Widget poster(BuildContext context) {
    final borderRadius = BorderRadius.circular(10);
    final posterUrl = channel.image ?? metadata?.poster;
    return AspectRatio(
      aspectRatio: 2 / 3,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
          ),
          child: posterUrl == null
              ? const Center(child: Icon(Icons.movie, size: 64))
              : CachedNetworkImage(
                  imageUrl: posterUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 480,
                  memCacheHeight: 720,
                  errorWidget: (_, _, _) =>
                      const Center(child: Icon(Icons.movie, size: 64)),
                ),
        ),
      ),
    );
  }

  Widget details(BuildContext context, {required bool compact}) {
    final textTheme = Theme.of(context).textTheme;
    final category = channel.group?.trim();
    final titleStyle = compact
        ? textTheme.titleLarge
        : textTheme.headlineMedium;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                channel.name,
                maxLines: compact ? 4 : null,
                overflow: compact ? TextOverflow.ellipsis : null,
                style: titleStyle?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: isFavorite ? 'Remove favorite' : 'Add favorite',
              onPressed: onToggleFavorite,
              icon: Icon(isFavorite ? Icons.star : Icons.star_border),
              color: isFavorite ? Colors.amber : null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              avatar: const Icon(Icons.movie, size: 18),
              label: const Text('Movie'),
            ),
            if (category != null && category.isNotEmpty)
              Chip(label: Text(category)),
          ],
        ),
        if (!compact) ...[
          const SizedBox(height: 28),
          actions(context),
          const SizedBox(height: 20),
          MetadataDetails(metadata: metadata),
          if (metadata?.backdrop?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 18),
            MetadataBackdrop(metadata: metadata),
          ],
        ],
      ],
    );
  }

  Widget actions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: onPlay,
          icon: const Icon(Icons.play_arrow),
          label: Text(actionLabel),
        ),
        if (hasResume) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onStartOver,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Start over'),
          ),
        ],
      ],
    );
  }
}
