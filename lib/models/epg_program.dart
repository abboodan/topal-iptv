class EpgProgram {
  final int? id;
  final int channelId;
  final int sourceId;
  final int streamId;
  final String title;
  final String? description;
  final int startTimestamp;
  final int stopTimestamp;
  final int fetchedAt;

  const EpgProgram({
    this.id,
    required this.channelId,
    required this.sourceId,
    required this.streamId,
    required this.title,
    this.description,
    required this.startTimestamp,
    required this.stopTimestamp,
    required this.fetchedAt,
  });

  DateTime get startTime => DateTime.fromMillisecondsSinceEpoch(
    startTimestamp * 1000,
    isUtc: true,
  ).toLocal();

  DateTime get stopTime => DateTime.fromMillisecondsSinceEpoch(
    stopTimestamp * 1000,
    isUtc: true,
  ).toLocal();
}

class EpgNowNext {
  final EpgProgram? current;
  final EpgProgram? next;

  const EpgNowNext({this.current, this.next});
}
