import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topal_iptv/live_browse.dart';
import 'package:topal_iptv/models/mobile_section.dart';
import 'package:topal_iptv/models/view_type.dart';

void main() {
  test('live browse header is limited to the root live section', () {
    expect(
      shouldShowLiveBrowseHeader(
        section: MobileSection.live,
        globalSearch: false,
        insideNode: false,
      ),
      isTrue,
    );
    expect(
      shouldShowLiveBrowseHeader(
        section: MobileSection.movies,
        globalSearch: false,
        insideNode: false,
      ),
      isFalse,
    );
    expect(
      shouldShowLiveBrowseHeader(
        section: MobileSection.live,
        globalSearch: true,
        insideNode: false,
      ),
      isFalse,
    );
    expect(
      shouldShowLiveBrowseHeader(
        section: MobileSection.live,
        globalSearch: false,
        insideNode: true,
      ),
      isFalse,
    );
  });

  test('live browse mode gives categories a direct all channels action', () {
    final mode = liveBrowseModeFor(
      viewType: ViewType.categories,
      hasQuery: false,
    );

    expect(mode.title, 'Live TV');
    expect(mode.actionLabel, 'All channels');
    expect(mode.actionViewType, ViewType.all);
  });

  test('live favorites empty state offers a browse action', () {
    final action = liveEmptyActionFor(
      section: MobileSection.live,
      viewType: ViewType.favorites,
      globalSearch: false,
    );

    expect(action?.label, 'Browse live channels');
    expect(action?.viewType, ViewType.categories);
  });

  test('EPG chip is only shown for the Live root section', () {
    expect(
      shouldShowLiveEpgChip(section: MobileSection.live, globalSearch: false),
      isTrue,
    );
    expect(
      shouldShowLiveEpgChip(section: MobileSection.movies, globalSearch: false),
      isFalse,
    );
    expect(
      shouldShowLiveEpgChip(section: MobileSection.live, globalSearch: true),
      isFalse,
    );
  });

  test('live EPG mode describes now and next listings', () {
    final mode = liveBrowseModeFor(viewType: ViewType.epg, hasQuery: false);

    expect(mode.title, 'Live EPG');
    expect(mode.actionLabel, 'All channels');
    expect(mode.actionViewType, ViewType.all);
  });

  testWidgets('browse empty state renders optional action', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrowseEmptyState(
            message: 'No favorite channels yet',
            actionLabel: 'Browse live channels',
            onAction: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('No favorite channels yet'), findsOneWidget);
    expect(find.text('Browse live channels'), findsOneWidget);

    await tester.tap(find.text('Browse live channels'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });
}
