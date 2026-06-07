import 'package:topal_iptv/models/mobile_section.dart';
import 'package:topal_iptv/models/view_type.dart';

enum ChannelTileLayout { category, row, live, poster }

class BrowseLayout {
  final ChannelTileLayout tileLayout;
  final double mainAxisExtent;
  final bool showMediaTypeLabel;

  const BrowseLayout({
    required this.tileLayout,
    required this.mainAxisExtent,
    this.showMediaTypeLabel = false,
  });

  factory BrowseLayout.forState({
    required MobileSection section,
    required ViewType viewType,
    bool hasQuery = false,
    bool globalSearch = false,
  }) {
    if (globalSearch) {
      return const BrowseLayout(
        tileLayout: ChannelTileLayout.row,
        mainAxisExtent: 100,
        showMediaTypeLabel: true,
      );
    }

    if (viewType == ViewType.categories && !hasQuery) {
      return const BrowseLayout(
        tileLayout: ChannelTileLayout.category,
        mainAxisExtent: 92,
      );
    }

    switch (section) {
      case MobileSection.live:
        return const BrowseLayout(
          tileLayout: ChannelTileLayout.live,
          mainAxisExtent: 76,
        );
      case MobileSection.movies:
      case MobileSection.series:
        return const BrowseLayout(
          tileLayout: ChannelTileLayout.poster,
          mainAxisExtent: 250,
        );
      case MobileSection.settings:
        return const BrowseLayout(
          tileLayout: ChannelTileLayout.row,
          mainAxisExtent: 100,
        );
    }
  }

  int crossAxisCount(double width) {
    switch (tileLayout) {
      case ChannelTileLayout.poster:
        return (width / 150).floor().clamp(2, 6);
      case ChannelTileLayout.live:
        return (width / 360).floor().clamp(1, 2);
      case ChannelTileLayout.category:
      case ChannelTileLayout.row:
        return (width / 350).floor().clamp(1, 3);
    }
  }

  String emptyMessage(MobileSection section) {
    if (showMediaTypeLabel) return 'No media found';
    if (tileLayout == ChannelTileLayout.category) return 'No categories found';
    switch (section) {
      case MobileSection.live:
        return 'No channels found';
      case MobileSection.movies:
        return 'No movies found';
      case MobileSection.series:
        return 'No series found';
      case MobileSection.settings:
        return 'No items found';
    }
  }
}
