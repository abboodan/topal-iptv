import 'package:topal_iptv/models/filters.dart';
import 'package:topal_iptv/models/stack.dart';

class Snapshot {
  final Stack stack;
  final Filters filters;
  Snapshot({required this.stack, required this.filters});
}
