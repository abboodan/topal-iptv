import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:topal_iptv/player_controls/player_control_profile.dart';

class PlayerControlActions {
  final VoidCallback onExit;
  final VoidCallback onSubtitles;
  final VoidCallback onAudio;
  final VoidCallback onZoom;
  final VoidCallback onRestart;
  final VoidCallback onSkipBackward;
  final VoidCallback onSkipForward;
  final VoidCallback? onPreviousLiveChannel;
  final VoidCallback? onNextLiveChannel;

  const PlayerControlActions({
    required this.onExit,
    required this.onSubtitles,
    required this.onAudio,
    required this.onZoom,
    required this.onRestart,
    required this.onSkipBackward,
    required this.onSkipForward,
    this.onPreviousLiveChannel,
    this.onNextLiveChannel,
  });
}

MaterialVideoControlsThemeData buildMaterialPlayerControlsTheme({
  required PlayerControlProfile profile,
  required String title,
  required PlayerControlActions actions,
  String? livePositionLabel,
}) {
  return MaterialVideoControlsThemeData(
    speedUpOnLongPress: false,
    seekOnDoubleTap: profile.seekOnDoubleTap,
    displaySeekBar: profile.displaySeekBar,
    seekBarMargin: const EdgeInsets.only(bottom: 60),
    seekBarThumbSize: 20,
    seekBarHeight: 10,
    seekGesture: profile.seekGesture,
    topButtonBar: [
      IconButton(
        onPressed: actions.onExit,
        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
      ),
      const SizedBox(width: 10),
      Text(title),
      if (profile.isLive) ...[
        const SizedBox(width: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Text(
              livePositionLabel == null ? 'LIVE' : 'LIVE $livePositionLabel',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    ],
    bottomButtonBar: [
      if (profile.isLive) ...[
        IconButton(
          tooltip: 'Previous channel',
          onPressed: actions.onPreviousLiveChannel,
          icon: const Icon(Icons.skip_previous, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 16),
      ],
      IconButton(
        tooltip: 'Subtitles',
        onPressed: actions.onSubtitles,
        icon: const Icon(Icons.subtitles, color: Colors.white, size: 32),
      ),
      const SizedBox(width: 16),
      IconButton(
        tooltip: 'Audio',
        onPressed: actions.onAudio,
        icon: const Icon(Icons.music_note, color: Colors.white, size: 32),
      ),
      if (!profile.isLive) ...[
        const SizedBox(width: 16),
        IconButton(
          tooltip: 'Back 10 seconds',
          onPressed: actions.onSkipBackward,
          icon: const Icon(Icons.replay_10, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 16),
        IconButton(
          tooltip: 'Restart',
          onPressed: actions.onRestart,
          icon: const Icon(Icons.restart_alt, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 16),
        IconButton(
          tooltip: 'Forward 10 seconds',
          onPressed: actions.onSkipForward,
          icon: const Icon(Icons.forward_10, color: Colors.white, size: 32),
        ),
      ],
      if (profile.isLive) ...[
        const SizedBox(width: 16),
        IconButton(
          tooltip: 'Next channel',
          onPressed: actions.onNextLiveChannel,
          icon: const Icon(Icons.skip_next, color: Colors.white, size: 32),
        ),
      ],
      const SizedBox(width: 16),
      IconButton(
        tooltip: 'Aspect ratio',
        icon: const Icon(
          Icons.aspect_ratio_outlined,
          color: Colors.white,
          size: 32,
        ),
        onPressed: actions.onZoom,
      ),
    ],
  );
}
