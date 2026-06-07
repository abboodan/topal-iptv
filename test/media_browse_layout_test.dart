import 'package:flutter_test/flutter_test.dart';
import 'package:topal_iptv/models/browse_layout.dart';
import 'package:topal_iptv/models/mobile_section.dart';
import 'package:topal_iptv/models/view_type.dart';

void main() {
  test('browse without a query uses category rows', () {
    final layout = BrowseLayout.forState(
      section: MobileSection.movies,
      viewType: ViewType.categories,
    );

    expect(layout.tileLayout, ChannelTileLayout.category);
    expect(layout.crossAxisCount(360), 1);
  });

  test('movies and series all views use poster grids', () {
    final movieLayout = BrowseLayout.forState(
      section: MobileSection.movies,
      viewType: ViewType.all,
    );
    final seriesLayout = BrowseLayout.forState(
      section: MobileSection.series,
      viewType: ViewType.all,
    );

    expect(movieLayout.tileLayout, ChannelTileLayout.poster);
    expect(seriesLayout.tileLayout, ChannelTileLayout.poster);
    expect(movieLayout.crossAxisCount(360), 2);
  });

  test('live all view uses a dense live row layout', () {
    final layout = BrowseLayout.forState(
      section: MobileSection.live,
      viewType: ViewType.all,
    );

    expect(layout.tileLayout, ChannelTileLayout.live);
    expect(layout.mainAxisExtent, 76);
  });

  test('global search keeps rows and shows media type labels', () {
    final layout = BrowseLayout.forState(
      section: MobileSection.series,
      viewType: ViewType.all,
      globalSearch: true,
    );

    expect(layout.tileLayout, ChannelTileLayout.row);
    expect(layout.showMediaTypeLabel, isTrue);
  });

  test('empty states describe the active browsing mode', () {
    final movies = BrowseLayout.forState(
      section: MobileSection.movies,
      viewType: ViewType.all,
    );
    final global = BrowseLayout.forState(
      section: MobileSection.live,
      viewType: ViewType.all,
      globalSearch: true,
    );

    expect(movies.emptyMessage(MobileSection.movies), 'No movies found');
    expect(global.emptyMessage(MobileSection.live), 'No media found');
  });
}
