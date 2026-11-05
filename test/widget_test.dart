import 'package:flutter_test/flutter_test.dart';
import 'package:finditbsu_app/providers/auth_provider.dart';

void main() {
  test('AuthProvider domain validation helper strictly checks @g.batstate-u.edu.ph', () {
    expect(AuthProvider.isBatStateUEmail('random@gmail.com'), isFalse);
    expect(AuthProvider.isBatStateUEmail('user@yahoo.com'), isFalse);
    expect(AuthProvider.isBatStateUEmail('test@batstate-u.edu.ph'), isFalse);
    expect(AuthProvider.isBatStateUEmail('john@outlook.com'), isFalse);
    expect(AuthProvider.isBatStateUEmail('21-12345@g.batstate-u.edu.ph'), isTrue);
    expect(AuthProvider.isBatStateUEmail('student.name@g.batstate-u.edu.ph'), isTrue);
  });
}
