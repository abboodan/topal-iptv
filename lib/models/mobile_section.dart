import 'package:topal_iptv/models/media_type.dart';

enum MobileSection { live, movies, series, settings }

extension MobileSectionData on MobileSection {
  String get label {
    switch (this) {
      case MobileSection.live:
        return 'Live';
      case MobileSection.movies:
        return 'Movies';
      case MobileSection.series:
        return 'Series';
      case MobileSection.settings:
        return 'Settings';
    }
  }

  MediaType? get mediaType {
    switch (this) {
      case MobileSection.live:
        return MediaType.livestream;
      case MobileSection.movies:
        return MediaType.movie;
      case MobileSection.series:
        return MediaType.serie;
      case MobileSection.settings:
        return null;
    }
  }

  List<MediaType> get mediaTypes {
    final type = mediaType;
    return type == null ? const [] : [type];
  }
}

MobileSection firstEnabledMobileSection(List<MediaType> mediaTypes) {
  if (mediaTypes.contains(MediaType.livestream)) return MobileSection.live;
  if (mediaTypes.contains(MediaType.movie)) return MobileSection.movies;
  if (mediaTypes.contains(MediaType.serie)) return MobileSection.series;
  return MobileSection.live;
}

MobileSection mobileSectionFromMediaTypes(List<MediaType>? mediaTypes) {
  if (mediaTypes == null || mediaTypes.isEmpty) return MobileSection.live;
  return firstEnabledMobileSection(mediaTypes);
}
