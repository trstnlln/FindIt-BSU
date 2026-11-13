import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/university_account.dart';

abstract final class AccountAccess {
  static Future<bool> approvedStaff(String uid) async {
    if (Firebase.apps.isEmpty) return false;
    final user = FirebaseAuth.instance.currentUser;
    if (user?.uid != uid) return false;
    return (await user!.getIdTokenResult()).claims?['staff'] == true;
  }

  static Future<bool> isMember(User user) async =>
      user.emailVerified &&
      (UniversityAccount.isCampusEmail(user.email ?? '') ||
          await approvedStaff(user.uid));
}
