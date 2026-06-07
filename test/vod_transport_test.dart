import 'package:flutter_test/flutter_test.dart';
import 'package:topal_iptv/player_controls/vod_transport.dart';

void main() {
  test('vod seek target clamps backward skips at zero', () {
    final target = vodSeekTarget(
      position: const Duration(seconds: 4),
      duration: const Duration(minutes: 1),
      delta: -const Duration(seconds: 10),
    );

    expect(target, Duration.zero);
  });

  test('vod seek target clamps forward skips at duration', () {
    final target = vodSeekTarget(
      position: const Duration(seconds: 55),
      duration: const Duration(minutes: 1),
      delta: const Duration(seconds: 10),
    );

    expect(target, const Duration(minutes: 1));
  });

  test('vod seek target allows forward skips when duration is unknown', () {
    final target = vodSeekTarget(
      position: const Duration(seconds: 55),
      duration: Duration.zero,
      delta: const Duration(seconds: 10),
    );

    expect(target, const Duration(seconds: 65));
  });
}
