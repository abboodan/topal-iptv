import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:topal_iptv/backend/settings_service.dart';
import 'package:topal_iptv/backend/sql.dart';
import 'package:topal_iptv/channel_variant_picker.dart';
import 'package:topal_iptv/models/browse_layout.dart';
import 'package:topal_iptv/models/channel.dart';
import 'package:topal_iptv/error.dart';
import 'package:topal_iptv/models/media_type.dart';
import 'package:topal_iptv/models/node.dart';
import 'package:topal_iptv/models/node_type.dart';
import 'package:topal_iptv/movie_detail.dart';
import 'package:topal_iptv/player.dart';
import 'package:topal_iptv/player_controls/live_channel_context.dart';
import 'package:topal_iptv/series_detail.dart';

class ChannelTile extends StatefulWidget {
  final Channel channel;
  final BuildContext parentContext;
  final Function(Node node) setNode;
  final VoidCallback? onFocusNavbar;
  final bool showMediaTypeLabel;
  final ChannelTileLayout layout;
  final LiveChannelContext? liveContext;
  const ChannelTile({
    super.key,
    required this.channel,
    required this.setNode,
    required this.parentContext,
    this.onFocusNavbar,
    this.showMediaTypeLabel = false,
    this.layout = ChannelTileLayout.row,
    this.liveContext,
  });

  @override
  State<ChannelTile> createState() => _ChannelTileState();
}

class _ChannelTileState extends State<ChannelTile> {
  final FocusNode _focusNode = FocusNode();
  @override
  void initState() {
    super.initState();
    _focusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (!FocusScope.of(
          context,
        ).focusInDirection(TraversalDirection.right)) {
          widget.onFocusNavbar?.call();
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
    _focusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> favorite() async {
    if (widget.channel.mediaType == MediaType.group) return;
    await Error.tryAsyncNoLoading(() async {
      await Sql.favoriteChannel(widget.channel.id!, !widget.channel.favorite);
      setState(() {
        widget.channel.favorite = !widget.channel.favorite;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Added to favorites"),
          duration: Duration(milliseconds: 500),
        ),
      );
    }, context);
  }

  Future<void> play() async {
    if (widget.channel.mediaType == MediaType.group) {
      widget.setNode(
        Node(
          id: widget.channel.id!,
          name: widget.channel.name,
          type: fromMediaType(widget.channel.mediaType),
        ),
      );
    } else if (widget.channel.mediaType == MediaType.serie) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SeriesDetailPage(series: widget.channel),
        ),
      );
    } else {
      if (widget.channel.mediaType == MediaType.movie &&
          widget.channel.seriesId == null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MovieDetailPage(channel: widget.channel),
          ),
        );
        return;
      }
      final selectedChannel = await chooseChannelVariant(
        context,
        widget.channel,
      );
      if (!mounted || selectedChannel == null) return;
      var settings = await SettingsService.getSettings();
      if (selectedChannel.id != null) {
        await Sql.addToHistory(selectedChannel.id!);
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Player(
            channel: selectedChannel,
            settings: settings,
            liveContext: widget.liveContext,
          ),
        ),
      );
    }
  }

  String get mediaTypeLabel {
    switch (widget.channel.mediaType) {
      case MediaType.livestream:
        return 'Live';
      case MediaType.movie:
        return 'Movie';
      case MediaType.serie:
        return 'Series';
      case MediaType.group:
        return 'Category';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.layout == ChannelTileLayout.poster) {
      return buildPosterTile(context);
    }
    return buildRowTile(context);
  }

  Widget buildPosterTile(BuildContext context) {
    return Card(
      elevation: _focusNode.hasFocus ? 8.0 : 2.0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: InkWell(
        focusNode: _focusNode,
        onLongPress: favorite,
        onTap: () async => await play(),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    color: Colors.black,
                    child: mediaImage(
                      context,
                      fit: BoxFit.cover,
                      iconSize: 42,
                      memCacheHeight: 480,
                      memCacheWidth: 320,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Text(
                    widget.channel.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.fontSize,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
            if (widget.channel.favorite)
              PositionedDirectional(
                top: 8,
                end: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.star, size: 18, color: Colors.amber),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget buildRowTile(BuildContext context) {
    final bool dense = widget.layout == ChannelTileLayout.live;
    return Card(
      elevation: _focusNode.hasFocus ? 8.0 : 2.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(dense ? 8 : 12),
      ),
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: InkWell(
        focusNode: _focusNode,
        onLongPress: favorite,
        onTap: () async => await play(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                padding: EdgeInsets.all(dense ? 10.0 : 8.0),
                child: Center(
                  child: mediaImage(
                    context,
                    fit: BoxFit.contain,
                    iconSize: dense ? 34 : 45,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.channel.name,
                        textAlign: TextAlign.left,
                        maxLines: widget.showMediaTypeLabel ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: Theme.of(
                            context,
                          ).textTheme.titleMedium?.fontSize!,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (widget.showMediaTypeLabel) ...[
                        const SizedBox(height: 4),
                        Text(
                          mediaTypeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: Theme.of(
                              context,
                            ).textTheme.labelLarge?.fontSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (widget.channel.favorite)
              Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: Center(
                  child: const Icon(Icons.star, size: 25, color: Colors.amber),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget mediaImage(
    BuildContext context, {
    required BoxFit fit,
    required double iconSize,
    int memCacheHeight = 300,
    int memCacheWidth = 300,
  }) {
    final fallbackIcon = Icon(
      widget.layout == ChannelTileLayout.category ? Icons.dashboard : Icons.tv,
      size: iconSize,
      color: Colors.grey,
    );
    if (widget.channel.image == null) return fallbackIcon;
    return CachedNetworkImage(
      imageUrl: widget.channel.image!,
      memCacheHeight: memCacheHeight,
      memCacheWidth: memCacheWidth,
      fit: fit,
      errorWidget: (_, _, _) => fallbackIcon,
    );
  }
}
