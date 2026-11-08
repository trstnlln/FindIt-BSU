import 'user_model.dart';

/// Profile information returned by a university Google sign-in, never inferred
/// from an email address or student number. This is not a student registry lookup.
class UniversityAccount {
  static const domain = 'g.batstate-u.edu.ph';
  final String name;
  final String email;
  final String? photoUrl;

  const UniversityAccount._(this.name, this.email, this.photoUrl);

  static bool isCampusEmail(String email) =>
      RegExp(r'^[^@\s]+@g\.batstate-u\.edu\.ph$')
          .hasMatch(email.trim().toLowerCase());

  factory UniversityAccount.fromGoogle({
    required String? email,
    required String? displayName,
    required bool emailVerified,
    String? photoUrl,
  }) {
    if (email == null || !isCampusEmail(email)) {
      throw const UniversityAccountException(
        'Choose your @g.batstate-u.edu.ph Google account to continue.',
      );
    }
    if (!emailVerified) {
      throw const UniversityAccountException(
        'Google could not verify this university email. Please use a verified university account.',
      );
    }
    final name = displayName?.trim() ?? '';
    if (name.isEmpty) {
      throw const UniversityAccountException(
        'Your Google account did not provide a name. You can register with email and enter your name instead.',
      );
    }
    if (name.length > 200) {
      throw const UniversityAccountException(
        'Your Google account name is too long. Use email registration with a name under 200 characters.',
      );
    }
    return UniversityAccount._(name, email.trim().toLowerCase(), photoUrl);
  }

  UserModel toProfile({
    required String uid,
    UserModel? existing,
    required DateTime now,
  }) => UserModel(
    id: uid,
    name: name,
    email: email,
    photoUrl: photoUrl ?? existing?.photoUrl,
    // Existing accounts keep their role and original creation date. New Google
    // registrations are students; a sign-in never changes an account's role.
    role: existing?.role ?? 'student',
    createdAt: existing?.createdAt ?? now,
  );
}

class UniversityAccountException implements Exception {
  final String message;
  const UniversityAccountException(this.message);
  @override
  String toString() => message;
}
