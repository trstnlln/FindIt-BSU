import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Manages authentication state for the entire app.
///
/// Listens to Firebase Auth state changes on startup so that a user who was
/// previously logged in stays logged in across app launches without any extra
/// work — Firebase persists the session automatically.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  bool _isInitialLoading = true;
  bool _isLoading = false;

  /// The currently logged-in user's profile, or null if not authenticated.
  UserModel? get currentUser => _currentUser;

  /// True while the app is checking for a saved session on cold start.
  bool get isInitialLoading => _isInitialLoading;

  /// True while an active auth operation (login/register) is in progress.
  bool get isLoading => _isLoading;

  /// Convenience getter — true if a user is signed in.
  bool get isLoggedIn => _currentUser != null;

  AuthProvider() {
    // Subscribe to Firebase auth changes immediately on creation.
    _authService.authStateChanges.listen((firebaseUser) async {
      await _onAuthStateChanged(firebaseUser);
      if (_isInitialLoading) {
        _isInitialLoading = false;
        notifyListeners();
      }
    });
  }

  // ─── Internal ─────────────────────────────────────────────────────────

  /// Called automatically by Firebase whenever auth state changes.
  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _currentUser = null;
    } else {
      try {
        _currentUser = await _authService.getUserData(firebaseUser.uid);
      } catch (e) {
        // Fallback user if firestore throws, so user is never locked out
        _currentUser = UserModel(
          id: firebaseUser.uid,
          name: firebaseUser.displayName?.isNotEmpty == true
              ? firebaseUser.displayName!
              : (firebaseUser.email?.split('@').first ?? 'BSU User'),
          email: firebaseUser.email ?? '',
          role: 'student',
          createdAt: DateTime.now(),
        );
      }
    }
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // ─── Public Actions ───────────────────────────────────────────────────

  /// Registers a new user. Returns an error message string on failure,
  /// or null on success.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    _setLoading(true);
    try {
      _currentUser = await _authService.registerWithEmail(
        name: name,
        email: email,
        password: password,
        role: role,
      );
      notifyListeners();
      return null; // null = success
    } on FirebaseAuthException catch (e) {
      return _mapFirebaseError(e.code);
    } catch (e) {
      return 'Registration failed: ${e.toString().replaceAll('Exception: ', '')}';
    } finally {
      _setLoading(false);
    }
  }

  /// Logs in an existing user. Returns an error message string on failure,
  /// or null on success.
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      _currentUser = await _authService.loginWithEmail(
        email: email,
        password: password,
      );
      notifyListeners();
      return null; // null = success
    } on FirebaseAuthException catch (e) {
      return _mapFirebaseError(e.code);
    } catch (e) {
      return 'Login failed: ${e.toString().replaceAll('Exception: ', '')}';
    } finally {
      _setLoading(false);
    }
  }

  /// One-click demo login for quickly testing the app.
  Future<String?> loginAsDemoUser({String role = 'student'}) async {
    _setLoading(true);
    try {
      const demoEmail = 'student.demo@g.batstate-u.edu.ph';
      const demoPass = 'Student@123';

      try {
        _currentUser = await _authService.loginWithEmail(
          email: demoEmail,
          password: demoPass,
        );
      } catch (_) {
        try {
          _currentUser = await _authService.registerWithEmail(
            name: 'Demo Student',
            email: demoEmail,
            password: demoPass,
            role: role,
          );
        } catch (_) {
          // If Firebase is offline or restricted, create local session
          _currentUser = UserModel(
            id: 'demo_student_alangilan',
            name: 'Demo Student',
            email: demoEmail,
            role: role,
            createdAt: DateTime.now(),
          );
        }
      }
      notifyListeners();
      return null;
    } catch (e) {
      return 'Demo login failed: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Signs the user out and clears local state.
  Future<void> logout() async {
    await _authService.logout();
    _currentUser = null;
    notifyListeners();
  }

  // ─── Error Mapping ────────────────────────────────────────────────────

  /// Converts Firebase error codes into readable messages for the UI.
  String _mapFirebaseError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please log in instead.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password. Please check your credentials or register.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again in a few minutes.';
      case 'network-request-failed':
        return 'Cannot connect to Firebase. Please check your internet connection.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is not enabled in Firebase Console.';
      case 'channel-error':
        return 'Please enter both your email and password.';
      default:
        return 'Authentication error ($code). Please try again.';
    }
  }
}
