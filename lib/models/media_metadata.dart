class MediaMetadata {
  final int? id;
  final int channelId;
  final int sourceId;
  final String? synopsis;
  final String? year;
  final String? rating;
  final int? durationSeconds;
  final List<String> genres;
  final List<String> cast;
  final String? backdrop;
  final String? poster;
  final int fetchedAt;

  const MediaMetadata({
    this.id,
    required this.channelId,
    required this.sourceId,
    this.synopsis,
    this.year,
    this.rating,
    this.durationSeconds,
    this.genres = const [],
    this.cast = const [],
    this.backdrop,
    this.poster,
    required this.fetchedAt,
  });

  bool get hasDetails {
    return (synopsis?.trim().isNotEmpty ?? false) ||
        (year?.trim().isNotEmpty ?? false) ||
        (rating?.trim().isNotEmpty ?? false) ||
        durationSeconds != null ||
        genres.isNotEmpty ||
        cast.isNotEmpty ||
        (backdrop?.trim().isNotEmpty ?? false) ||
        (poster?.trim().isNotEmpty ?? false);
  }
}
