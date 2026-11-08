import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:finditbsu_app/models/university_account.dart';
import 'package:finditbsu_app/models/user_model.dart';
import 'package:finditbsu_app/providers/auth_provider.dart';
import 'package:finditbsu_app/screens/auth/login_screen.dart';
import 'package:finditbsu_app/screens/auth/register_screen.dart';
import 'package:finditbsu_app/services/auth_service.dart';
import 'package:finditbsu_app/theme/app_theme.dart';

class PendingGoogleUser extends Fake implements User {}

class GoogleAuthTestService extends AuthService {
  final changes = StreamController<User?>.broadcast();
  final result = Completer<UserModel>();
  int attempts = 0;
  int signOuts = 0;
  @override
  Stream<User?> get authStateChanges => changes.stream;
  @override
  Future<UserModel> signInWithUniversityGoogle() {
    attempts++;
    return result.future;
  }

  @override
  Future<void> logout() async {
    signOuts++;
  }
}

void main() {
  UniversityAccount identity({
    String? email = '21-12345@g.batstate-u.edu.ph',
    String? name = '  María Dela Cruz  ',
    bool verified = true,
  }) => UniversityAccount.fromGoogle(
    email: email,
    displayName: name,
    emailVerified: verified,
    photoUrl: 'https://example.com/photo.jpg',
  );

  test(
    'imports Google name even when email contains only a student number',
    () {
      final profile = identity().toProfile(uid: 'student', now: DateTime(2026));
      expect(profile.name, 'María Dela Cruz');
      expect(profile.email, '21-12345@g.batstate-u.edu.ph');
      expect(profile.role, 'student');
      expect(profile.photoUrl, 'https://example.com/photo.jpg');
    },
  );
  test(
    'rejects personal, spoofed, missing, and unverified university identities',
    () {
      for (final email in [
        'person@gmail.com',
        'student@g.batstate-u.edu.ph.evil.com',
        '@g.batstate-u.edu.ph',
        null,
      ]) {
        expect(
          () => identity(email: email),
          throwsA(isA<UniversityAccountException>()),
        );
      }
      expect(
        () => identity(verified: false),
        throwsA(isA<UniversityAccountException>()),
      );
    },
  );
  test('never guesses a name from email when Google returns no name', () {
    for (final name in [null, '', '   ', 'x' * 201]) {
      expect(
        () => identity(name: name),
        throwsA(isA<UniversityAccountException>()),
      );
    }
  });
  test(
    'updates imported name while preserving existing role and account age',
    () {
      final original = UserModel(
        id: 'teacher',
        name: 'Old name',
        email: '21-12345@g.batstate-u.edu.ph',
        role: 'teacher',
        createdAt: DateTime(2020),
      );
      final profile = identity().toProfile(
        uid: 'teacher',
        existing: original,
        now: DateTime(2026),
      );
      expect(profile.name, 'María Dela Cruz');
      expect(profile.role, 'teacher');
      expect(profile.createdAt, DateTime(2020));
    },
  );
  test(
    'Google sign-in creates the local profile without a typed name',
    () async {
      final service = GoogleAuthTestService();
      final auth = AuthProvider(authService: service);
      final signIn = auth.signInWithUniversityGoogle();
      expect(auth.isLoading, isTrue);
      expect(await auth.signInWithUniversityGoogle(), isNotNull);
      expect(service.attempts, 1);
      service.result.complete(
        identity().toProfile(uid: 'student', now: DateTime(2026)),
      );
      expect(await signIn, isNull);
      expect(auth.currentUser?.name, 'María Dela Cruz');
      expect(auth.isLoading, isFalse);
      auth.dispose();
      await service.changes.close();
    },
  );
  test(
    'logout during Google sign-in cannot restore the local session',
    () async {
      final service = GoogleAuthTestService();
      final auth = AuthProvider(authService: service);
      final signIn = auth.signInWithUniversityGoogle();
      await auth.logout();
      service.result.complete(
        identity().toProfile(uid: 'student', now: DateTime(2026)),
      );
      expect(await signIn, isNotNull);
      expect(auth.currentUser, isNull);
      auth.dispose();
      await service.changes.close();
    },
  );
  test('personal account errors stay signed out and allow retry', () async {
    final service = GoogleAuthTestService();
    final auth = AuthProvider(authService: service);
    final signIn = auth.signInWithUniversityGoogle();
    service.result.completeError(
      const UniversityAccountException('Choose your university account.'),
    );
    expect(await signIn, 'Choose your university account.');
    expect(auth.currentUser, isNull);
    expect(auth.isLoading, isFalse);
    auth.dispose();
    await service.changes.close();
  });

  test(
    'closing the Google popup leaves the user signed out without an error',
    () async {
      final service = GoogleAuthTestService();
      final auth = AuthProvider(authService: service);
      final signIn = auth.signInWithUniversityGoogle();
      service.result.completeError(
        FirebaseAuthException(code: 'popup-closed-by-user'),
      );
      expect(await signIn, isNull);
      expect(auth.currentUser, isNull);
      expect(auth.isLoading, isFalse);
      auth.dispose();
      await service.changes.close();
    },
  );
  test(
    'a non-campus profile cannot enter the app even if the service returns it',
    () async {
      final service = GoogleAuthTestService();
      final auth = AuthProvider(authService: service);
      final signIn = auth.signInWithUniversityGoogle();
      service.result.complete(
        UserModel(
          id: 'outsider',
          name: 'Outsider',
          email: 'person@gmail.com',
          role: 'student',
          createdAt: DateTime(2026),
        ),
      );
      expect(await signIn, isNotNull);
      expect(auth.currentUser, isNull);
      expect(service.signOuts, 1);
      auth.dispose();
      await service.changes.close();
    },
  );

  for (final registration in [false, true]) {
    testWidgets(
      '${registration ? 'registration' : 'login'} Google action works with empty manual fields',
      (tester) async {
        tester.view.physicalSize = const Size(320, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = GoogleAuthTestService();
        final auth = AuthProvider(authService: service);
        addTearDown(auth.dispose);
        addTearDown(service.changes.close);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: auth,
            child: MaterialApp(
              theme: AppTheme.light,
              home: registration ? const RegisterScreen() : const LoginScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final action = find.text('Continue with university Google account');
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pump();
        expect(service.attempts, 1);
        expect(find.text('Please enter your full name.'), findsNothing);
        expect(find.text('Please enter your password.'), findsNothing);
        service.result.completeError(
          const UniversityAccountException('Choose your university account.'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Choose your university account.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
