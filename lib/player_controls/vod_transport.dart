Duration vodSeekTarget({
  required Duration position,
  required Duration duration,
  required Duration delta,
}) {
  final target = position + delta;
  if (target < Duration.zero) return Duration.zero;
  if (duration > Duration.zero && target > duration) return duration;
  return target;
}
