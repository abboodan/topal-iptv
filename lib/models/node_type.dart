import 'package:topal_iptv/models/exceptions/invalid_value_exception.dart';
import 'package:topal_iptv/models/media_type.dart';

enum NodeType { category, series }

NodeType fromMediaType(MediaType type) {
  switch (type) {
    case MediaType.group:
      return NodeType.category;
    case MediaType.serie:
      return NodeType.series;
    case MediaType.livestream:
      throw InvalidValueException(MediaType.livestream.toString());
    case MediaType.movie:
      throw InvalidValueException(MediaType.livestream.toString());
  }
}
