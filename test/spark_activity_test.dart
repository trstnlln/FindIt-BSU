import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:finditbsu_app/models/activity_entry.dart';
import 'package:finditbsu_app/models/claim_model.dart';
import 'package:finditbsu_app/models/item_model.dart';
import 'package:finditbsu_app/models/university_account.dart';
import 'package:finditbsu_app/providers/activity_provider.dart';
import 'package:finditbsu_app/screens/activity/my_activity_screen.dart';
import 'package:finditbsu_app/services/activity_service.dart';
import 'package:finditbsu_app/theme/app_theme.dart';

ClaimModel claim({
  String id = 'claim',
  String itemId = 'report',
  String status = 'pending',
}) => ClaimModel(
  id: id,
  itemId: itemId,
  itemTitle: 'A campus calculator',
  ownerId: 'finder',
  claimantId: 'student',
  proof: 'private ownership answer',
  status: status,
  createdAt: DateTime(2026, 11, 1),
  updatedAt: DateTime(2026, 11, 2),
);
ItemModel report(String id, {bool archived = false}) => ItemModel(
  id: id,
  type: 'found',
  title: id,
  description: 'A long description',
  category: 'Electronics',
  location: 'Library',
  date: DateTime(2026, 11, 1),
  status: 'open',
  ownerId: 'finder',
  createdAt: DateTime(2026, 11, 1),
  archived: archived,
);

class Feed {
  final reports = StreamController<List<ItemModel>>.broadcast();
  final incoming = StreamController<List<ClaimModel>>.broadcast();
  final submitted = StreamController<List<ClaimModel>>.broadcast();
  final owner = StreamController<Map<String, Map<String, dynamic>>>.broadcast();
  final claimant =
      StreamController<Map<String, Map<String, dynamic>>>.broadcast();
  final reads = StreamController<Map<String, String>>.broadcast();
  void load() {
    reports.add([]);
    incoming.add([]);
    submitted.add([]);
    owner.add({});
    claimant.add({});
    reads.add({});
  }

  Future<void> close() async {
    await Future.wait([
      reports.close(),
      incoming.close(),
      submitted.close(),
      owner.close(),
      claimant.close(),
      reads.close(),
    ]);
  }
}

class FakeActivity extends ActivityService {
  final feeds = <String, Feed>{};
  Feed feed(String uid) => feeds.putIfAbsent(uid, Feed.new);
  final writes = <String>[];
  Completer<void>? pending;
  @override
  Stream<List<ItemModel>> reports(String uid) => feed(uid).reports.stream;
  @override
  Stream<List<ClaimModel>> incoming(String uid) => feed(uid).incoming.stream;
  @override
  Stream<List<ClaimModel>> submitted(String uid) => feed(uid).submitted.stream;
  @override
  Stream<Map<String, Map<String, dynamic>>> conversations(
    String uid,
    String field,
  ) => field == 'ownerId' ? feed(uid).owner.stream : feed(uid).claimant.stream;
  @override
  Stream<Map<String, String>> reads(String uid) => feed(uid).reads.stream;
  @override
  Future<void> markRead(String uid, String id, String version) async {
    writes.add('$uid/$id/$version');
    await pending?.future;
  }

  Future<void> close() async {
    for (final feed in feeds.values) {
      await feed.close();
    }
  }
}

Future<void> flush() => Future<void>.delayed(Duration.zero);
void main() {
  test(
    'live updates hide proof and only flag incoming messages and claim changes',
    () {
      final entries = deriveActivity(
        uid: 'student',
        incoming: [],
        submitted: [claim(status: 'ready')],
        conversations: {
          'claim': {
            'lastSenderId': 'finder',
            'lastMessageId': 'm1',
            'lastMessageAt': 1,
            'itemId': 'report',
            'itemTitle': 'Calculator',
            'text': 'a secret',
          },
          'mine': {
            'lastSenderId': 'student',
            'lastMessageId': 'm2',
            'lastMessageAt': 2,
          },
        },
      );
      expect(entries.length, 2);
      expect(entries.where((e) => e.message).single.version, 'm1');
      expect(
        entries.any(
          (e) =>
              e.body.contains('private ownership') ||
              e.body.contains('a secret'),
        ),
        isFalse,
      );
      expect(
        deriveActivity(
          uid: 'student',
          incoming: [],
          submitted: [claim()],
          conversations: {},
        ),
        isEmpty,
      );
    },
  );
  test(
    'receipts follow message versions and do not cross account switches',
    () async {
      final service = FakeActivity();
      final activity = ActivityProvider(service: service);
      activity.bind('student');
      final first = service.feed('student');
      first.load();
      first.claimant.add({
        'claim': {
          'lastSenderId': 'finder',
          'lastMessageId': 'm1',
          'lastMessageAt': 1,
          'itemId': 'report',
        },
      });
      await flush();
      expect(activity.unreadCount, 1);
      await activity.markRead(activity.entries.single);
      expect(activity.unreadCount, 0);
      first.claimant.add({
        'claim': {
          'lastSenderId': 'finder',
          'lastMessageId': 'm2',
          'lastMessageAt': 2,
          'itemId': 'report',
        },
      });
      await flush();
      expect(activity.unreadCount, 1);
      service.pending = Completer<void>();
      final read = activity.markRead(activity.entries.single);
      activity.bind('other');
      service.feed('other').load();
      service.pending!.complete();
      await read;
      await flush();
      expect(activity.entries, isEmpty);
      expect(activity.unreadCount, 0);
      expect(activity.hasError, isFalse);
      first.incoming.add([claim()]);
      await flush();
      expect(activity.entries, isEmpty);
      activity.dispose();
      await service.close();
    },
  );
  test(
    'staff with another domain need trusted approval and a verified email',
    () {
      expect(
        () => UniversityAccount.fromGoogle(
          email: 'employee@example.org',
          displayName: 'Employee',
          emailVerified: true,
        ),
        throwsA(isA<UniversityAccountException>()),
      );
      expect(
        () => UniversityAccount.fromGoogle(
          email: 'employee@example.org',
          displayName: 'Employee',
          emailVerified: false,
          approvedStaff: true,
        ),
        throwsA(isA<UniversityAccountException>()),
      );
      final staff = UniversityAccount.fromGoogle(
        email: 'employee@example.org',
        displayName: 'Employee',
        emailVerified: true,
        approvedStaff: true,
      );
      expect(staff.toProfile(uid: 'staff', now: DateTime(2026)).role, 'staff');
    },
  );
  test('archiving retains report identity and survives edits', () {
    final archived = report('history', archived: true);
    expect(ItemModel.fromMap(archived.toMap(), 'history').archived, isTrue);
    expect(archived.copyWith(title: 'Edited title').archived, isTrue);
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'activity prioritizes review tasks and fits large text $scale',
      (tester) async {
        tester.view.physicalSize = const Size(390, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = FakeActivity();
        final activity = ActivityProvider(service: service)..bind('finder');
        final feed = service.feed('finder');
        feed.load();
        feed.reports.add([
          report('Old history', archived: true),
          report('Needs review'),
          report('No action'),
        ]);
        feed.incoming.add([claim(itemId: 'Needs review')]);
        await tester.pump();
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: activity,
            child: MaterialApp(
              theme: AppTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const MyActivityScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Review claims (1)'), findsOneWidget);
        await tester.tap(find.text('Needs attention'));
        await tester.pumpAndSettle();
        expect(find.text('Needs review'), findsOneWidget);
        expect(find.text('Old history'), findsNothing);
        expect(find.text('No action'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        activity.dispose();
        await service.close();
      },
    );
  }
}
