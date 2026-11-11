import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finditbsu_app/models/item_model.dart';
import 'package:finditbsu_app/theme/app_theme.dart';
import 'package:finditbsu_app/widgets/campus_header.dart';
import 'package:finditbsu_app/widgets/campus_report_feed.dart';
import 'package:finditbsu_app/widgets/item_card.dart';

ItemModel report({String status = 'open'}) => ItemModel(
  id: 'report',
  type: 'found',
  title: 'Scientific calculator with a very long identifying description',
  description: 'Red sticker on the cover',
  category: 'Electronics',
  location: 'College of Informatics & Computing Sciences',
  specificLocation: 'Second floor',
  custodyLocation: 'Library Front Desk',
  date: DateTime(2026, 11, 1),
  status: status,
  ownerId: 'finder',
  createdAt: DateTime(2026, 11, 1),
);

Widget host(Widget child, {double scale = 1}) => MaterialApp(
  theme: AppTheme.light,
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(body: child),
  ),
);

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'campus header and cards fit narrow screens at text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          host(
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const CampusAppBarTitle(
                      name:
                          'A student with a very long university account name',
                    ),
                    const CampusWelcome(),
                    for (final status in ['open', 'claimed', 'returned'])
                      ItemCard(item: report(status: status)),
                  ],
                ),
              ),
            ),
            scale: scale,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Safe at Library Front Desk'), findsNWidgets(2));
        expect(find.text('RETURNED'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'feed failure hides technical errors and retries with a fresh stream',
    (tester) async {
      var source = Stream<List<ItemModel>>.error(
        StateError('private backend details'),
      );
      var retries = 0;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) => CampusReportFeed(
              itemsStream: source,
              type: 'found',
              searchQuery: '',
              selectedCategory: null,
              selectedLocation: null,
              selectedStatus: null,
              selectedDate: null,
              onResetFilters: () {},
              onRetry: () => setState(() {
                retries++;
                source = Stream.value([report()]);
              }),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Couldn’t load campus reports'), findsOneWidget);
      expect(find.textContaining('private backend details'), findsNothing);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(retries, 1);
      expect(find.byType(ItemCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('search includes custody and empty results can reset filters', (
    tester,
  ) async {
    final source = Stream.value([report()]);
    var query = 'does not exist';
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => CampusReportFeed(
            itemsStream: source,
            type: 'found',
            searchQuery: query,
            selectedCategory: null,
            selectedLocation: null,
            selectedStatus: null,
            selectedDate: null,
            onRetry: () {},
            onResetFilters: () => setState(() => query = 'library front desk'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No matches just yet'), findsOneWidget);
    await tester.tap(find.text('Reset Search & Filters'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
