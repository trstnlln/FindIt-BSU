import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart';
import 'package:finditbsu_app/models/item_model.dart';
import 'package:finditbsu_app/models/user_model.dart';
import 'package:finditbsu_app/providers/auth_provider.dart';
import 'package:finditbsu_app/providers/item_provider.dart';
import 'package:finditbsu_app/screens/report/report_item_screen.dart';
import 'package:finditbsu_app/screens/auth/login_screen.dart';
import 'package:finditbsu_app/services/auth_service.dart';
import 'package:finditbsu_app/theme/app_theme.dart';
import 'package:finditbsu_app/widgets/brand_logo.dart';
import 'package:finditbsu_app/widgets/item_card.dart';

class TestAuthService extends AuthService {
  final changes = StreamController<User?>.broadcast();
  final result = Completer<UserModel>();
  int loginCount = 0;
  String? submittedEmail;
  @override
  Stream<User?> get authStateChanges => changes.stream;
  @override
  Future<void> logout() async {}

  @override
  Future<UserModel> loginWithEmail({
    required String email,
    required String password,
  }) {
    loginCount++;
    submittedEmail = email;
    return result.future;
  }
}

void main() {
  test('campus email validation rejects malformed and spoofed identities', () {
    for (final value in [
      '@g.batstate-u.edu.ph',
      'x@@g.batstate-u.edu.ph',
      'a b@g.batstate-u.edu.ph',
      'a@g.batstate-u.edu.ph.evil.com',
      '',
    ]) {
      expect(AuthProvider.isBatStateUEmail(value), isFalse, reason: value);
    }
    expect(
      AuthProvider.isBatStateUEmail(' Student@g.batstate-u.edu.ph '),
      isTrue,
    );
  });

  test(
    'in-flight login is guarded and completion after disposal is safe',
    () async {
      final service = TestAuthService();
      final provider = AuthProvider(authService: service);
      final request = provider.login(
        email: ' Student@g.batstate-u.edu.ph ',
        password: 'password',
      );
      expect(
        await provider.login(
          email: 'student@g.batstate-u.edu.ph',
          password: 'password',
        ),
        isNotNull,
      );
      expect(service.loginCount, 1);
      expect(service.submittedEmail, 'student@g.batstate-u.edu.ph');
      provider.dispose();
      service.result.complete(
        UserModel(
          id: 'u1',
          name: 'Student',
          email: 'student@g.batstate-u.edu.ph',
          role: 'student',
          createdAt: DateTime(2026),
        ),
      );
      expect(await request, isNotNull);
      await service.changes.close();
    },
  );

  test('a slow login cannot restore a session after logout', () async {
    final service = TestAuthService();
    final provider = AuthProvider(authService: service);
    final request = provider.login(
      email: 'student@g.batstate-u.edu.ph',
      password: 'password',
    );
    await provider.logout();
    service.result.complete(
      UserModel(
        id: 'u1',
        name: 'Student',
        email: 'student@g.batstate-u.edu.ph',
        role: 'student',
        createdAt: DateTime(2026),
      ),
    );
    expect(await request, isNotNull);
    expect(provider.currentUser, isNull);
    provider.dispose();
    await service.changes.close();
  });

  for (final width in [320.0, 390.0, 768.0]) {
    testWidgets('sign in is readable and validates fields at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = TestAuthService();
      final provider = AuthProvider(authService: service);
      addTearDown(provider.dispose);
      addTearDown(service.changes.close);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BrandLogo), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Register'), findsNothing);
      await tester.ensureVisible(find.text('Sign in with email instead'));
      await tester.tap(find.text('Sign in with email instead'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(2));
      await tester.ensureVisible(find.text('Log In'));
      await tester.tap(find.text('Log In'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter your email.'), findsOneWidget);
      expect(find.text('Please enter your password.'), findsOneWidget);
      expect(service.loginCount, 0);
      await tester.ensureVisible(find.text('Use university Google instead'));
      await tester.tap(find.text('Use university Google instead'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Please enter your email.'), findsNothing);
    });
  }

  for (final layout in [(1200.0, 1.0), (500.0, 2.0)]) {
    testWidgets('login balances its footer and scrolls at $layout', (
      tester,
    ) async {
      final (height, scale) = layout;
      tester.view.physicalSize = Size(390, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = TestAuthService();
      final provider = AuthProvider(authService: service);
      addTearDown(provider.dispose);
      addTearDown(service.changes.close);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final footer = find.text('Meet on campus');
      if (scale == 1) {
        expect(tester.getBottomRight(footer).dy, lessThan(height));
        expect(tester.getBottomRight(footer).dy, greaterThan(height * .75));
      }
      await tester.ensureVisible(footer);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sign in with email instead'));
      await tester.tap(find.text('Sign in with email instead'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Log In'));
      await tester.tap(find.text('Log In'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter your email.'), findsOneWidget);
      expect(find.text('Please enter your password.'), findsOneWidget);
    });
  }

  testWidgets('desktop without Google support keeps email sign-in available', (
    tester,
  ) async {
    final service = TestAuthService();
    final provider = AuthProvider(authService: service);
    addTearDown(provider.dispose);
    addTearDown(service.changes.close);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Continue with university Google account'), findsNothing);
    expect(find.text('Sign in with email instead'), findsNothing);
    expect(find.text('Register'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.windows}));

  testWidgets(
    'found money report shows private verification on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider = ItemProvider();
      addTearDown(provider.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const ReportItemScreen(),
          ),
        ),
      );
      await tester.tap(find.text('I found an item'));
      await tester.pumpAndSettle();
      final category = find.byType(DropdownButtonFormField<String>).first;
      await tester.ensureVisible(category);
      await tester.tap(category);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Money').last);
      await tester.tap(find.text('Money').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Private verification details'));
      await tester.pumpAndSettle();
      expect(find.text('Correct answer 1'), findsOneWidget);
    },
  );

  testWidgets('long item details fit a narrow screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final item = ItemModel(
      id: '1',
      type: 'found',
      title: 'Blue university water bottle with a very long identifying description',
      description: 'Description',
      category: 'Water Bottle / Tumbler',
      location: 'College of Informatics & Computing Sciences',
      custodyLocation: 'Campus Security Office',
      date: DateTime(2026),
      status: 'open',
      ownerId: 'finder',
      createdAt: DateTime(2026),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(
            body: SingleChildScrollView(child: ItemCard(item: item)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Safe at Campus Security Office'), findsOneWidget);
    expect(find.text('View details'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
