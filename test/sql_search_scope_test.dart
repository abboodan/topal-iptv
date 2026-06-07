import 'package:flutter_test/flutter_test.dart';
import 'package:topal_iptv/backend/sql.dart';
import 'package:topal_iptv/models/filters.dart';
import 'package:topal_iptv/models/media_type.dart';
import 'package:topal_iptv/models/view_type.dart';

void main() {
  test('category root searches groups only when no query is entered', () {
    final filters = Filters(
      viewType: ViewType.categories,
      mediaTypes: [MediaType.movie],
      sourceIds: [1],
    );

    expect(Sql.shouldSearchGroups(filters), isTrue);

    filters.query = '   ';

    expect(Sql.shouldSearchGroups(filters), isTrue);
  });

  test('category root with a query searches media items instead of groups', () {
    final filters = Filters(
      viewType: ViewType.categories,
      mediaTypes: [MediaType.serie],
      sourceIds: [1],
      query: 'breaking',
    );

    expect(Sql.shouldSearchGroups(filters), isFalse);
  });
}
