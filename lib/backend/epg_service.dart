import 'package:topal_iptv/backend/sql.dart';
import 'package:topal_iptv/backend/xtream.dart';
import 'package:topal_iptv/models/channel.dart';
import 'package:topal_iptv/models/epg_program.dart';
import 'package:topal_iptv/models/media_type.dart';

const Duration epgCacheTtl = Duration(hours: 6);
const int epgFetchConcurrency = 3;

typedef EpgProgramFetcher = Future<List<EpgProgram>> Function(Channel channel);

Future<void> refreshEpgForChannels(
  List<Channel> channels, {
  DateTime? now,
  Duration ttl = epgCacheTtl,
  int maxConcurrent = epgFetchConcurrency,
  EpgProgramFetcher? fetchPrograms,
}) async {
  final fetcher = fetchPrograms ?? getShortEpgPrograms;
  final candidates = <Channel>[];

  for (final channel in channels) {
    if (channel.mediaType != MediaType.livestream ||
        channel.id == null ||
        channel.streamId == null) {
      continue;
    }
    final fresh = await Sql.isEpgCacheFresh(channel.id!, now: now, ttl: ttl);
    if (!fresh) candidates.add(channel);
  }

  if (candidates.isEmpty) return;

  var nextIndex = 0;
  final workerCount = maxConcurrent.clamp(1, candidates.length);

  Future<void> worker() async {
    while (nextIndex < candidates.length) {
      final channel = candidates[nextIndex++];
      try {
        final programs = await fetcher(channel);
        await Sql.replaceEpgPrograms(channel.id!, programs);
      } catch (_) {
        // Keep EPG best-effort; browsing and playback must not fail because
        // one provider EPG request failed.
      }
    }
  }

  await Future.wait(List.generate(workerCount, (_) => worker()));
}
