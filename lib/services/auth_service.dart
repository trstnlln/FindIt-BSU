import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user_model.dart';
import '../models/university_account.dart';
import 'account_access.dart';
import 'device_alerts.dart';

/// Handles all Firebase Auth and Firestore user operations.
/// Screens never call Firebase directly — they go through this service.
class AuthService {
  static Future<void>? _googleInitialization;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ─── Auth State ──────────────────────────────────────────────────────────

  /// Stream that emits whenever the user logs in or out.
  /// Returns null when logged out, a Firebase [User] when logged in.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// The currently signed-in Firebase user, or null if logged out.
  User? get currentFirebaseUser => _auth.currentUser;

  // ─── Registration ────────────────────────────────────────────────────────

  /// Creates a new Firebase Auth account, updates the display name,
  /// then writes the full user profile to the `users` Firestore collection.
  Future<UserModel> registerWithEmail({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    // 1. Create the auth account
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // 2. Update the display name in Firebase Auth
    await credential.user!.updateDisplayName(name);

    // 3. Build the UserModel to persist in Firestore
    final user = UserModel(
      id: credential.user!.uid,
      name: name,
      email: email,
      role: role,
      createdAt: DateTime.now(),
    );

    // 4. Save to Firestore — document ID matches the Firebase Auth UID
    await _db.collection('users').doc(user.id).set(user.toMap());

    try {
      await credential.user!.sendEmailVerification();
    } on FirebaseAuthException {
      // Account creation succeeded; the verification screen supports resend.
    }
    return user;
  }

  // ─── Login ───────────────────────────────────────────────────────────────

  /// Signs in an existing user and returns their Firestore profile.
  Future<UserModel> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return getUserData(credential.user!.uid);
  }

  Future<bool> isApprovedStaff(String uid) => AccountAccess.approvedStaff(uid);

  /// Imports the profile only after Firebase accepts Google's sign-in token.
  /// The domain selector is a convenience; the returned identity is validated
  /// independently before any profile is written.
  Future<UserModel> signInWithUniversityGoogle() async {
    UserCredential credential;
    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..setCustomParameters({'prompt': 'select_account'});
      credential = await _auth.signInWithPopup(provider);
    } else {
      if (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS &&
          defaultTargetPlatform != TargetPlatform.macOS) {
        throw FirebaseAuthException(code: 'university-sign-in-unavailable');
      }
      final signIn = GoogleSignIn.instance;
      const serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
      const configuredClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
      final apple =
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS;
      final clientId = configuredClientId.isNotEmpty
          ? configuredClientId
          : Firebase.app().options.iosClientId;
      if (apple && (clientId == null || clientId.isEmpty)) {
        throw FirebaseAuthException(code: 'university-sign-in-unavailable');
      }
      try {
        await (_googleInitialization ??= signIn.initialize(
          clientId: apple ? clientId : null,
          serverClientId: serverClientId.isEmpty ? null : serverClientId,
        ));
      } catch (_) {
        _googleInitialization = null;
        rethrow;
      }
      final account = await signIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw FirebaseAuthException(code: 'invalid-credential');
      }
      credential = await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    }

    final firebaseUser = credential.user;
    try {
      if (firebaseUser == null) {
        throw FirebaseAuthException(code: 'invalid-credential');
      }
      final googleProfiles = firebaseUser.providerData.where(
        (provider) => provider.providerId == 'google.com',
      );
      if (googleProfiles.isEmpty) {
        throw FirebaseAuthException(code: 'invalid-credential');
      }
      final googleProfile = googleProfiles.first;
      final identity = UniversityAccount.fromGoogle(
        email: firebaseUser.email,
        approvedStaff: await isApprovedStaff(firebaseUser.uid),
        displayName: googleProfile.displayName,
        emailVerified: firebaseUser.emailVerified,
        photoUrl: googleProfile.photoURL,
      );
      final ref = _db.collection('users').doc(firebaseUser.uid);
      // Do not fall back on failed reads here: preserve existing account data
      // and show a retry message rather than silently replacing its profile.
      final profile = await _db.runTransaction<UserModel>((transaction) async {
        final snapshot = await transaction.get(ref);
        final existing = snapshot.exists && snapshot.data() != null
            ? UserModel.fromMap(snapshot.data()!, snapshot.id)
            : null;
        final user = identity.toProfile(
          uid: firebaseUser.uid,
          existing: existing,
          now: DateTime.now(),
        );
        transaction.set(ref, user.toMap(), SetOptions(merge: true));
        return user;
      });
      return profile;
    } catch (_) {
      // A rejected personal account or failed profile save must never leave
      // an authenticated session that bypasses the registration screen.
      await _auth.signOut();
      rethrow;
    }
  }

  // ─── User Data ───────────────────────────────────────────────────────────

  /// Fetches a user's profile from Firestore by their UID.
  /// If the Firestore profile does not exist yet (e.g. created in console),
  /// a temporary fallback is constructed without overwriting stored data.
  Future<UserModel> getUserData(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();

      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
    } catch (_) {
      // Continue to fallback if firestore read fails or document is missing
    }

    // Fallback: construct UserModel from Auth info
    final fbUser = _auth.currentUser;
    final fallbackUser = UserModel(
      id: uid,
      name: fbUser?.displayName?.isNotEmpty == true
          ? fbUser!.displayName!
          : (fbUser?.email?.split('@').first ?? 'BSU User'),
      email: fbUser?.email ?? '',
      role: await isApprovedStaff(uid) ? 'staff' : 'student',
      createdAt: DateTime.now(),
    );

    // Never write fallback data after a failed read: doing so can overwrite
    // an existing profile while the device is offline or access is denied.
    return fallbackUser;
  }

  Future<void> sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'user-not-found');
    if (!user.emailVerified) await user.sendEmailVerification();
  }

  Future<User?> refreshIdentity() async {
    await _auth.currentUser?.reload();
    final user = _auth.currentUser;
    if (user?.emailVerified == true) await user!.getIdToken(true);
    return user;
  }

  Future<void> resetPassword(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());

  // ─── Logout ──────────────────────────────────────────────────────────────

  /// Signs the current user out of Firebase Auth.
  Future<void> logout() async {
    await DeviceAlerts.disableCurrentDevice().timeout(
      const Duration(seconds: 3),
      onTimeout: () {},
    );
    await _auth.signOut();
  }
}
