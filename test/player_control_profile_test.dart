import 'package:flutter_test/flutter_test.dart';
import 'package:topal_iptv/models/media_type.dart';
import 'package:topal_iptv/player_controls/player_control_profile.dart';

void main() {
  test('live profile disables seeking and reconnects on completion', () {
    final profile = PlayerControlProfile.forMediaType(MediaType.livestream);

    expect(profile.experience, PlayerExperience.live);
    expect(profile.displaySeekBar, isFalse);
    expect(profile.seekGesture, isFalse);
    expect(profile.seekOnDoubleTap, isFalse);
    expect(profile.restorePosition, isFalse);
    expect(profile.savePositionOnExit, isFalse);
    expect(profile.reconnectOnCompletion, isTrue);
  });

  test('vod profile keeps seeking and resume behavior enabled', () {
    final profile = PlayerControlProfile.forMediaType(MediaType.movie);

    expect(profile.experience, PlayerExperience.vod);
    expect(profile.displaySeekBar, isTrue);
    expect(profile.seekGesture, isTrue);
    expect(profile.seekOnDoubleTap, isTrue);
    expect(profile.restorePosition, isTrue);
    expect(profile.savePositionOnExit, isTrue);
    expect(profile.reconnectOnCompletion, isFalse);
  });

  test('series is treated as a non-live player experience if routed there', () {
    final profile = PlayerControlProfile.forMediaType(MediaType.serie);

    expect(profile.experience, PlayerExperience.vod);
    expect(profile.displaySeekBar, isTrue);
    expect(profile.reconnectOnCompletion, isFalse);
  });
}
