import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:topal_iptv/backend/metadata_service.dart';
import 'package:topal_iptv/backend/settings_service.dart';
import 'package:topal_iptv/backend/sql.dart';
import 'package:topal_iptv/backend/xtream.dart';
import 'package:topal_iptv/channel_variant_picker.dart';
import 'package:topal_iptv/error.dart';
import 'package:topal_iptv/media_metadata_view.dart';
import 'package:topal_iptv/memory.dart';
import 'package:topal_iptv/models/channel.dart';
import 'package:topal_iptv/models/filters.dart';
import 'package:topal_iptv/models/media_metadata.dart';
import 'package:topal_iptv/models/media_type.dart';
import 'package:topal_iptv/models/view_type.dart';
import 'package:topal_iptv/player.dart';

class SeriesEpisodeGroup {
  final String label;
  final List<Channel> episodes;

  const SeriesEpisodeGroup({required this.label, required this.episodes});
}

List<SeriesEpisodeGroup> groupEpisodesBySeason(List<Channel> episodes) {
  final grouped = <String, List<Channel>>{};

  for (final episode in episodes) {
    final label = inferSeasonLabel(episode.name);
    grouped.putIfAbsent(label, () => []).add(episode);
  }

  return grouped.entries
      .map(
        (entry) => SeriesEpisodeGroup(label: entry.key, episodes: entry.value),
      )
      .toList();
}

String inferSeasonLabel(String name) {
  final patterns = [
    RegExp(r'\bS(?:eason)?\s*0*(\d{1,2})\b', caseSensitive: false),
    RegExp(r'\b0*(\d{1,2})x\d{1,3}\b', caseSensitive: false),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(name);
    if (match == null) continue;
    final season = int.tryParse(match.group(1) ?? '');
    if (season != null && season > 0) return 'Season $season';
  }

  return 'Episodes';
}

class SeriesDetailPage extends StatefulWidget {
  final Channel series;

  const SeriesDetailPage({super.key, required this.series});

  @override
  State<SeriesDetailPage> createState() => _SeriesDetailPageState();
}

class _SeriesDetailPageState extends State<SeriesDetailPage> {
  bool loading = true;
  String? error;
  List<Channel> episodes = [];
  MediaMetadata? metadata;

  int? get seriesId => int.tryParse(widget.series.url ?? '');

  @override
  void initState() {
    super.initState();
    unawaited(loadMetadata());
    loadEpisodes();
  }

  Future<void> loadMetadata() async {
    final loadedMetadata = await loadMediaMetadata(widget.series);
    if (!mounted) return;
    setState(() => metadata = loadedMetadata);
  }

  Future<void> loadEpisodes() async {
    final id = seriesId;
    if (id == null) {
      setState(() {
        loading = false;
        error = 'Series identifier is missing';
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      if (widget.series.id != null &&
          !refreshedSeries.contains(widget.series.id)) {
        await getEpisodes(widget.series);
        refreshedSeries.add(widget.series.id!);
      }

      final loadedEpisodes = await Sql.search(
        Filters(
          viewType: ViewType.all,
          mediaTypes: [MediaType.movie],
          sourceIds: [widget.series.sourceId],
          seriesId: id,
        ),
      );

      if (!mounted) return;
      setState(() {
        episodes = loadedEpisodes;
        loading = false;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = exception.toString();
      });
    }
  }

  Future<void> playEpisode(Channel episode) async {
    await Error.tryAsyncNoLoading(() async {
      final selectedEpisode = await chooseChannelVariant(context, episode);
      if (!mounted || selectedEpisode == null) return;
      final settings = await SettingsService.getSettings();
      if (selectedEpisode.id != null) {
        await Sql.addToHistory(selectedEpisode.id!);
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Player(channel: selectedEpisode, settings: settings),
        ),
      );
    }, context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.series.name)),
      body: SafeArea(
        child: SeriesDetailBody(
          series: widget.series,
          metadata: metadata,
          episodes: episodes,
          loading: loading,
          error: error,
          onRetry: loadEpisodes,
          onEpisodeSelected: playEpisode,
        ),
      ),
    );
  }
}

class SeriesDetailBody extends StatelessWidget {
  final Channel series;
  final MediaMetadata? metadata;
  final List<Channel> episodes;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final ValueChanged<Channel> onEpisodeSelected;

  const SeriesDetailBody({
    super.key,
    required this.series,
    this.metadata,
    required this.episodes,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onEpisodeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final groups = groupEpisodesBySeason(episodes);
    final rows = <_SeriesRow>[
      for (final group in groups) ...[
        _SeriesRow.header(group.label),
        for (final episode in group.episodes) _SeriesRow.episode(episode),
      ],
    ];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: header(context)),
        if (loading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (error != null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 42),
                    const SizedBox(height: 12),
                    Text(error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (rows.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('No episodes found')),
          )
        else
          SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              if (row.label != null) return seasonHeader(context, row.label!);
              return episodeRow(context, row.episode!);
            },
          ),
      ],
    );
  }

  Widget header(BuildContext context) {
    final category = series.group?.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 132, child: poster(context)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      series.name,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.video_library, size: 18),
                          label: const Text('Series'),
                        ),
                        if (category != null && category.isNotEmpty)
                          Chip(label: Text(category)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          MetadataDetails(metadata: metadata, includeDuration: false),
          if (metadata?.backdrop?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 18),
            MetadataBackdrop(metadata: metadata),
          ],
        ],
      ),
    );
  }

  Widget poster(BuildContext context) {
    final posterUrl = series.image ?? metadata?.poster;
    return AspectRatio(
      aspectRatio: 2 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
          ),
          child: posterUrl == null
              ? const Center(child: Icon(Icons.video_library, size: 54))
              : CachedNetworkImage(
                  imageUrl: posterUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 480,
                  memCacheHeight: 720,
                  errorWidget: (_, _, _) =>
                      const Center(child: Icon(Icons.video_library, size: 54)),
                ),
        ),
      ),
    );
  }

  Widget seasonHeader(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget episodeRow(BuildContext context, Channel episode) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: SizedBox(
        width: 72,
        height: 54,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
            ),
            child: episode.image == null
                ? const Icon(Icons.play_circle_outline)
                : CachedNetworkImage(
                    imageUrl: episode.image!,
                    fit: BoxFit.cover,
                    memCacheWidth: 216,
                    memCacheHeight: 162,
                    errorWidget: (_, _, _) =>
                        const Icon(Icons.play_circle_outline),
                  ),
          ),
        ),
      ),
      title: Text(episode.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.play_arrow),
      onTap: () => onEpisodeSelected(episode),
    );
  }
}

class _SeriesRow {
  final String? label;
  final Channel? episode;

  const _SeriesRow.header(this.label) : episode = null;

  const _SeriesRow.episode(this.episode) : label = null;
}
