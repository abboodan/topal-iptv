import 'package:topal_iptv/models/media_type.dart';

enum PlayerExperience { live, vod }

class PlayerControlProfile {
  final PlayerExperience experience;
  final bool displaySeekBar;
  final bool seekGesture;
  final bool seekOnDoubleTap;
  final bool restorePosition;
  final bool savePositionOnExit;
  final bool reconnectOnCompletion;

  const PlayerControlProfile({
    required this.experience,
    required this.displaySeekBar,
    required this.seekGesture,
    required this.seekOnDoubleTap,
    required this.restorePosition,
    required this.savePositionOnExit,
    required this.reconnectOnCompletion,
  });

  bool get isLive => experience == PlayerExperience.live;

  static PlayerControlProfile forMediaType(MediaType mediaType) {
    if (mediaType == MediaType.livestream) return live;
    return vod;
  }

  static const live = PlayerControlProfile(
    experience: PlayerExperience.live,
    displaySeekBar: false,
    seekGesture: false,
    seekOnDoubleTap: false,
    restorePosition: false,
    savePositionOnExit: false,
    reconnectOnCompletion: true,
  );

  static const vod = PlayerControlProfile(
    experience: PlayerExperience.vod,
    displaySeekBar: true,
    seekGesture: true,
    seekOnDoubleTap: true,
    restorePosition: true,
    savePositionOnExit: true,
    reconnectOnCompletion: false,
  );
}
