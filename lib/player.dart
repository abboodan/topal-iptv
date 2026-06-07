import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:topal_iptv/backend/sql.dart';
import 'package:topal_iptv/models/channel.dart';
import 'package:topal_iptv/models/id_data.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkvideo;
import 'package:topal_iptv/models/settings.dart';
import 'package:topal_iptv/player_controls/live_channel_context.dart';
import 'package:topal_iptv/player_controls/material_player_controls.dart';
import 'package:topal_iptv/player_controls/player_control_profile.dart';
import 'package:topal_iptv/player_controls/vod_transport.dart';
import 'package:topal_iptv/select_dialog.dart';

class Player extends StatefulWidget {
  final Channel channel;
  final Settings settings;
  final LiveChannelContext? liveContext;
  const Player({
    super.key,
    required this.channel,
    required this.settings,
    this.liveContext,
  });
  @override
  State<StatefulWidget> createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  static const vodSkipInterval = Duration(seconds: 10);

  late mk.Player player = mk.Player();
  late mkvideo.VideoController videoController = mkvideo.VideoController(
    player,
  );
  late final GlobalKey<VideoState> key = GlobalKey<VideoState>();
  late Channel currentChannel;
  LiveChannelContext? liveContext;
  bool exiting = false;
  bool fill = false;
  List<StreamSubscription> subscriptions = [];

  PlayerControlProfile get controlProfile =>
      PlayerControlProfile.forMediaType(currentChannel.mediaType);

  @override
  void initState() {
    super.initState();
    currentChannel = widget.channel;
    liveContext = widget.liveContext;
    mk.MediaKit.ensureInitialized();
    initAsync();
  }

  Future<void> initAsync() async {
    player.setPlaylistMode(mk.PlaylistMode.none);
    await setMpvOptions();
    final seconds = controlProfile.restorePosition
        ? await Sql.getPosition(currentChannel.id!)
        : null;
    await _startPlayback(seconds != null ? Duration(seconds: seconds) : null);
    subscriptions.add(
      player.stream.completed.listen((completed) {
        if (completed) onDisconnect();
      }),
    );
  }

  Future<void> setMpvOptions() async {
    if (player.platform is mk.NativePlayer) {
      final nativePlayer = player.platform as mk.NativePlayer;
      if (controlProfile.isLive) {
        if (widget.settings.lowLatency) {
          await nativePlayer.setProperty('profile', 'low-latency');
        }
      }
    }
  }

  void onDisconnect() async {
    if (!mounted || exiting) return;
    if (controlProfile.reconnectOnCompletion) {
      debugPrint("Live stream dropped/error. Attempting to reconnect...");
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || exiting) return;
      await _startPlayback(null);
    }
  }

  Future<void> _startPlayback(Duration? startPosition) async {
    while (true) {
      if (!mounted || exiting) return;
      try {
        final headers = await Sql.getChannelHeaders(currentChannel.id!);
        await player.open(
          mk.Media(
            currentChannel.url!,
            start: startPosition,
            httpHeaders: headers != null
                ? {
                    if (headers.referrer != null) "Referer": headers.referrer!,
                    if (headers.httpOrigin != null)
                      "Origin": headers.httpOrigin!,
                    if (headers.userAgent != null)
                      "User-Agent": headers.userAgent!,
                  }
                : null,
          ),
        );
        await key.currentState?.enterFullscreen();
        return;
      } catch (e) {
        debugPrint("Playback failed: $e. Retrying in 2s...");
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  @override
  void dispose() {
    for (final s in subscriptions) s.cancel();
    player.dispose();
    super.dispose();
  }

  Future<void> openSubtitlesModal() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => SelectDialog(
        title: "Select subtitles",
        action: (id) async {
          player.setSubtitleTrack(player.state.tracks.subtitle[id]);
          Navigator.of(context).pop();
        },
        data: player.state.tracks.subtitle
            .asMap()
            .entries
            .map(
              (entry) => IdData(
                id: entry.key,
                data: entry.value.language != null
                    ? "${entry.value.language} - ${entry.value.id}"
                    : entry.value.id,
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> openAudioModal() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => SelectDialog(
        title: "Select audio",
        action: (id) async {
          player.setAudioTrack(player.state.tracks.audio[id]);
          Navigator.of(context).pop();
        },
        data: player.state.tracks.audio
            .asMap()
            .entries
            .map(
              (entry) => IdData(
                id: entry.key,
                data:
                    entry.value.title ?? entry.value.language ?? entry.value.id,
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        onExit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: MaterialVideoControlsTheme(
          normal: getThemeData(context),
          fullscreen: getThemeData(context),
          child: Video(
            key: key,
            controller: videoController,
            onExitFullscreen: () async => onExit(),
          ),
        ),
      ),
    );
  }

  void onExit() async {
    if (exiting) return;
    exiting = true;
    if (controlProfile.savePositionOnExit) {
      Sql.setPosition(currentChannel.id!, player.state.position.inSeconds);
    }
    if (key.currentState!.isFullscreen()) {
      await key.currentState!.exitFullscreen();
    }
    Navigator.of(context).pop();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void toggleZoom() {
    final videoAspectRatio = player.state.width! / player.state.height!;
    final deviceAspectRatio = MediaQuery.of(context).size.aspectRatio;
    key.currentState!.update(
      aspectRatio: fill ? videoAspectRatio : deviceAspectRatio,
    );
    setState(() {
      fill = !fill;
    });
  }

  Future<void> restartVod() async {
    if (controlProfile.isLive) return;
    await player.seek(Duration.zero);
    await player.play();
  }

  Future<void> skipVodBy(Duration delta) async {
    if (controlProfile.isLive) return;
    await player.seek(
      vodSeekTarget(
        position: player.state.position,
        duration: player.state.duration,
        delta: delta,
      ),
    );
  }

  Future<void> switchLiveChannel(LiveChannelContext? nextContext) async {
    if (!controlProfile.isLive || nextContext == null || exiting) return;
    setState(() {
      liveContext = nextContext;
      currentChannel = nextContext.current;
    });
    if (currentChannel.id != null) {
      await Sql.addToHistory(currentChannel.id!);
    }
    await _startPlayback(null);
  }

  MaterialVideoControlsThemeData getThemeData(BuildContext context) {
    return buildMaterialPlayerControlsTheme(
      profile: controlProfile,
      title: currentChannel.name,
      livePositionLabel: liveContext?.positionLabel,
      actions: PlayerControlActions(
        onExit: onExit,
        onSubtitles: openSubtitlesModal,
        onAudio: openAudioModal,
        onZoom: toggleZoom,
        onRestart: restartVod,
        onSkipBackward: () => skipVodBy(-vodSkipInterval),
        onSkipForward: () => skipVodBy(vodSkipInterval),
        onPreviousLiveChannel: () =>
            switchLiveChannel(liveContext?.previousContext()),
        onNextLiveChannel: () => switchLiveChannel(liveContext?.nextContext()),
      ),
    );
  }
}
