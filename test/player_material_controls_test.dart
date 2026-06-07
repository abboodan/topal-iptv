import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topal_iptv/player_controls/material_player_controls.dart';
import 'package:topal_iptv/player_controls/player_control_profile.dart';

void main() {
  final actions = PlayerControlActions(
    onExit: () {},
    onSubtitles: () {},
    onAudio: () {},
    onZoom: () {},
    onRestart: () {},
    onSkipBackward: () {},
    onSkipForward: () {},
    onPreviousLiveChannel: () {},
    onNextLiveChannel: () {},
  );

  test(
    'material controls apply live seek restrictions and channel controls',
    () {
      final theme = buildMaterialPlayerControlsTheme(
        profile: PlayerControlProfile.live,
        title: 'Live News',
        actions: actions,
        livePositionLabel: '2 / 3',
      );

      expect(theme.displaySeekBar, isFalse);
      expect(theme.seekGesture, isFalse);
      expect(theme.seekOnDoubleTap, isFalse);
      expect(theme.topButtonBar.whereType<Text>().single.data, 'Live News');
      expect(theme.topButtonBar.whereType<DecoratedBox>(), isNotEmpty);
      expect(theme.bottomButtonBar.whereType<IconButton>(), hasLength(5));
      expect(
        theme.bottomButtonBar.whereType<IconButton>().map(
          (button) => button.tooltip,
        ),
        isNot(contains('Restart')),
      );
      expect(
        theme.bottomButtonBar.whereType<IconButton>().map(
          (button) => button.tooltip,
        ),
        containsAll(['Previous channel', 'Next channel']),
      );
    },
  );

  test('material controls keep vod seeking and transport controls enabled', () {
    final theme = buildMaterialPlayerControlsTheme(
      profile: PlayerControlProfile.vod,
      title: 'Example Movie',
      actions: actions,
    );

    expect(theme.displaySeekBar, isTrue);
    expect(theme.seekGesture, isTrue);
    expect(theme.seekOnDoubleTap, isTrue);
    expect(theme.topButtonBar.whereType<Text>().single.data, 'Example Movie');
    expect(theme.bottomButtonBar.whereType<IconButton>(), hasLength(6));
    expect(
      theme.bottomButtonBar.whereType<IconButton>().map(
        (button) => button.tooltip,
      ),
      containsAll(['Restart', 'Back 10 seconds', 'Forward 10 seconds']),
    );
  });
}
