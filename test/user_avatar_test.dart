import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finditbsu_app/theme/app_theme.dart';
import 'package:finditbsu_app/widgets/user_avatar.dart';

Widget host(String name, {String? photo}) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: Center(
      child: UserAvatar(name: name, photoUrl: photo),
    ),
  ),
);

void main() {
  testWidgets('missing and invalid pictures fall back to the account initial', (
    tester,
  ) async {
    for (final photo in [
      null,
      '',
      '   ',
      'not a URL',
      'http://example.org/photo.png',
    ]) {
      await tester.pumpWidget(host('  Tristan', photo: photo));
      expect(find.text('T'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(tester.getSize(find.byType(UserAvatar)), const Size(64, 64));
    }
    await tester.pumpWidget(host('👩🏽‍🎓 Student'));
    expect(find.text('👩🏽‍🎓'), findsOneWidget);
    await tester.pumpWidget(host('   '));
    expect(find.text('U'), findsOneWidget);
  });

  testWidgets(
    'an unavailable Google picture keeps the initial and does not crash',
    (tester) async {
      // Flutter's test HTTP client returns 400; no real Google account is fetched.
      await tester.pumpWidget(
        host('Tristan', photo: 'https://example.org/missing-profile.png'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('T'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'switching to an account without a picture clears the previous image',
    (tester) async {
      await tester.pumpWidget(
        host('Tristan', photo: 'https://example.org/photo.png'),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(host('Another student'));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.text('A'), findsOneWidget);
    },
  );
}
