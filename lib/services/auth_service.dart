import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

/// Handles all Firebase Auth and Firestore user operations.
/// Screens never call Firebase directly — they go through this service.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

  // ─── User Data ───────────────────────────────────────────────────────────

  /// Fetches a user's profile from Firestore by their UID.
  /// If the Firestore profile does not exist yet (e.g. created in console),
  /// a fallback profile is constructed and saved so the user is never locked out.
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
      role: 'student',
      createdAt: DateTime.now(),
    );

    // Attempt to persist profile to Firestore
    try {
      await _db.collection('users').doc(uid).set(fallbackUser.toMap());
    } catch (_) {}

    return fallbackUser;
  }

  // ─── Logout ──────────────────────────────────────────────────────────────

  /// Signs the current user out of Firebase Auth.
  Future<void> logout() async {
    await _auth.signOut();
  }
}
