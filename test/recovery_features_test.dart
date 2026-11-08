import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finditbsu_app/services/photo_upload.dart';
import 'package:finditbsu_app/services/report_draft_store.dart';
import 'package:finditbsu_app/services/auth_service.dart';
import 'package:finditbsu_app/providers/auth_provider.dart';
import 'package:finditbsu_app/models/user_model.dart';
import 'package:finditbsu_app/models/claim_model.dart';
import 'package:finditbsu_app/models/item_model.dart';
import 'package:finditbsu_app/models/document_dates.dart';
import 'package:finditbsu_app/screens/community/saved_search_results_screen.dart';
import 'package:finditbsu_app/widgets/claim_journey.dart';
import 'package:finditbsu_app/screens/auth/verify_email_screen.dart';
import 'package:finditbsu_app/theme/app_theme.dart';

class VerificationUser extends Fake implements User {
  final bool verified;
  VerificationUser(this.verified);
  @override
  bool get emailVerified => verified;
  @override
  String get uid => 'student';
  @override
  String get email => '21-12345@g.batstate-u.edu.ph';
}

class VerificationService extends AuthService {
  final changes = StreamController<User?>.broadcast();
  int sends = 0;
  @override
  Stream<User?> get authStateChanges => changes.stream;
  @override
  Future<void> sendVerificationEmail() async {
    sends++;
  }

  @override
  Future<User?> refreshIdentity() async => VerificationUser(true);
  @override
  Future<UserModel> getUserData(String uid) async => UserModel(
    id: uid,
    name: 'Student',
    email: '21-12345@g.batstate-u.edu.ph',
    role: 'student',
    createdAt: DateTime(2026),
  );
}

void main() {
  test(
    'invalid legacy dates cannot crash the feed or appear as new reports',
    () {
      for (final value in [
        null,
        double.nan,
        double.infinity,
        999999999999999999,
        'invalid',
      ]) {
        expect(parseDocumentDate(value).millisecondsSinceEpoch, 0);
      }
      expect(parseDocumentDate('2026-01-01T00:00:00Z'), DateTime.utc(2026));
      final report = ItemModel.fromMap({
        'date': 999999999999999999,
        'createdAt': 999999999999999999,
      }, 'legacy');
      expect(report.date.millisecondsSinceEpoch, 0);
    },
  );

  test('photo validation checks actual bytes and limits size', () {
    expect(
      validateReportPhoto(Uint8List.fromList([255, 216, 255, 0])).mime,
      'image/jpeg',
    );
    expect(
      validateReportPhoto(Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]))
          .extension,
      'png',
    );
    expect(
      () => validateReportPhoto(Uint8List.fromList('%PDF-1.4'.codeUnits)),
      throwsFormatException,
    );
    expect(
      () => validateReportPhoto(Uint8List(5 * 1024 * 1024 + 1)),
      throwsFormatException,
    );
    expect(() => validateReportPhoto(Uint8List(0)), throwsFormatException);
  });
  test('multipart upload progress counts bytes and completes at one', () async {
    final values = <double>[];
    final request = ProgressMultipartRequest(
      'POST',
      Uri.parse('https://example.com'),
      onProgress: values.add,
    )..fields['test'] = 'body';
    final chunks = await request.finalize().toList();
    expect(chunks.expand((c) => c).length, request.contentLength);
    expect(values.last, 1);
    expect(values.every((v) => v >= 0 && v <= 1), isTrue);
  });
  test(
    'drafts restore per user without persisting private verification or photos',
    () async {
      SharedPreferences.setMockInitialValues({});
      final drafts = ReportDraftStore();
      await drafts.save('student', {
        'title': 'Calculator',
        'description': 'Black calculator',
        'exactAmount': '500',
        'answers': ['secret'],
        'photoBytes': [1, 2, 3],
      });
      final restored = await drafts.load('student');
      expect(restored?['title'], 'Calculator');
      expect(restored?.containsKey('answers'), isFalse);
      expect(restored?.containsKey('exactAmount'), isFalse);
      expect(restored?.containsKey('photoBytes'), isFalse);
      expect(await drafts.load('other'), isNull);
      await drafts.clear('student');
      expect(await drafts.load('student'), isNull);
    },
  );
  test(
    'saved search results use keywords and selected filters consistently',
    () {
      final item = ItemModel(
        id: 'i',
        type: 'found',
        title: 'Black Casio calculator',
        description: 'Scientific calculator found in the library',
        category: 'Electronics',
        location: 'Library',
        date: DateTime(2026),
        status: 'open',
        ownerId: 'finder',
        createdAt: DateTime(2026),
      );
      expect(
        savedSearchMatches({
          'query': 'casio calculator',
          'category': 'Electronics',
        }, item),
        isTrue,
      );
      expect(savedSearchMatches({'query': 'wallet'}, item), isFalse);
      expect(
        savedSearchMatches({'query': '', 'category': 'Clothing'}, item),
        isFalse,
      );
      expect(savedSearchMatches({}, item), isFalse);
      expect(
        savedSearchMatches({
          'query': 'calculator',
        }, item.copyWith(status: 'returned')),
        isFalse,
      );
    },
  );

  test('claim copies preserve private ownership answers', () {
    final claim = ClaimModel(
      id: 'c',
      itemId: 'i',
      itemTitle: 'Wallet',
      ownerId: 'finder',
      claimantId: 'student',
      claimantName: 'Student',
      claimantEmail: 'student@g.batstate-u.edu.ph',
      message: 'Mine',
      proof: 'Red lining',
      verificationAnswers: const ['Two cards'],
      status: 'pending',
      createdAt: DateTime(2026),
    );
    expect(claim.copyWith(status: 'reviewing').verificationAnswers, [
      'Two cards',
    ]);
  });
  for (final status in [
    'pending',
    'reviewing',
    'approved',
    'ready',
    'returned',
    'rejected',
  ]) {
    testWidgets('claim journey $status fits narrow screens with large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ClaimJourney(status: status),
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        find.text(
          status == 'rejected' ? 'Claim not approved' : 'Your recovery journey',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('verification can resend and refresh without exposing the feed', (
    tester,
  ) async {
    final service = VerificationService();
    final auth = AuthProvider(authService: service);
    addTearDown(auth.dispose);
    addTearDown(service.changes.close);
    service.changes.add(VerificationUser(false));
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const VerifyEmailScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(auth.isEmailVerified, isFalse);
    await tester.tap(find.text('Resend verification email'));
    await tester.pumpAndSettle();
    expect(service.sends, 1);
    await tester.tap(find.text('I’ve verified my email'));
    await tester.pumpAndSettle();
    expect(auth.isEmailVerified, isTrue);
    expect(tester.takeException(), isNull);
  });
}
