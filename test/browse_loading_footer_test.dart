import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topal_iptv/live_browse.dart';

void main() {
  testWidgets('browse loading footer renders a compact progress state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CustomScrollView(slivers: [BrowseLoadingFooter()]),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading more'), findsOneWidget);
  });
}
