import 'package:flutter_test/flutter_test.dart';
import 'package:topal_iptv/load_request_guard.dart';

void main() {
  test('only the latest started request can update state', () {
    final guard = LoadRequestGuard();

    final first = guard.begin();
    final second = guard.begin();

    expect(guard.isCurrent(first), isFalse);
    expect(guard.isCurrent(second), isTrue);
  });

  test('load more lock prevents overlapping pagination work', () {
    final guard = LoadRequestGuard();

    expect(guard.tryBeginLoadMore(), isTrue);
    expect(guard.tryBeginLoadMore(), isFalse);

    guard.endLoadMore();

    expect(guard.tryBeginLoadMore(), isTrue);
  });
}
