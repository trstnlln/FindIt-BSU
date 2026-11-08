import 'dart:async';

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
  final AuthService _authService;

  UserModel? _currentUser;
  bool _isInitialLoading = true;
  bool _isLoading = false;
  bool _disposed = false;
  int _authRevision = 0;
  int _sessionRevision = 0;
  StreamSubscription<User?>? _authSubscription;

  /// The currently logged-in user's profile, or null if not authenticated.
  UserModel? get currentUser => _currentUser;

  /// True while the app is checking for a saved session on cold start.
  bool get isInitialLoading => _isInitialLoading;

  /// True while an active auth operation (login/register) is in progress.
  bool get isLoading => _isLoading;

  /// Convenience getter — true if a user is signed in.
  bool get isLoggedIn => _currentUser != null;

  AuthProvider({AuthService? authService})
    : _authService = authService ?? AuthService() {
    // Subscribe to Firebase auth changes immediately on creation.
    _authSubscription = _authService.authStateChanges.listen(
      (firebaseUser) async {
        await _onAuthStateChanged(firebaseUser);
        if (_isInitialLoading) {
          _isInitialLoading = false;
          notifyListeners();
        }
      },
      onError: (Object error, StackTrace stack) {
        _currentUser = null;
        _isInitialLoading = false;
        notifyListeners();
      },
    );
  }

  // ─── Internal ─────────────────────────────────────────────────────────

  /// Called automatically by Firebase whenever auth state changes.
  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    final revision = ++_authRevision;
    if (firebaseUser == null) {
      ++_sessionRevision;
      _currentUser = null;
    } else {
      final email = firebaseUser.email ?? '';
      // Strict domain restriction: if not @g.batstate-u.edu.ph, force logout
      if (!isBatStateUEmail(email)) {
        await _authService.logout();
        _currentUser = null;
        notifyListeners();
        return;
      }
      try {
        final user = await _authService.getUserData(firebaseUser.uid);
        if (_disposed || revision != _authRevision) return;
        _currentUser = user;
      } catch (e) {
        if (_disposed || revision != _authRevision) return;
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

  /// Returns true if [email] ends with the official @g.batstate-u.edu.ph domain.
  static bool isBatStateUEmail(String email) {
    return RegExp(r'^[^@\s]+@g\.batstate-u\.edu\.ph$')
        .hasMatch(email.trim().toLowerCase());
  }

  // ─── Public Actions ───────────────────────────────────────────────────

  /// Registers a new user. Returns an error message string on failure,
  /// or null on success. Strictly restricted to @g.batstate-u.edu.ph.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    if (!isBatStateUEmail(email)) {
      return 'Registration restricted: You must use an official @g.batstate-u.edu.ph email address.';
    }
    if (_isLoading) return 'Please wait for the current request to finish.';
    final session = _sessionRevision;
    _setLoading(true);
    try {
      final user = await _authService.registerWithEmail(
        name: name,
        email: email.trim().toLowerCase(),
        password: password,
        role: role,
      );
      if (_disposed || session != _sessionRevision) {
        return 'Session changed. Please sign in again.';
      }
      _currentUser = user;
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
  /// or null on success. Strictly restricted to @g.batstate-u.edu.ph.
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    if (!isBatStateUEmail(email)) {
      return 'Access Denied: Only users with a valid @g.batstate-u.edu.ph email address can log in.';
    }
    if (_isLoading) return 'Please wait for the current request to finish.';
    final session = _sessionRevision;
    _setLoading(true);
    try {
      final user = await _authService.loginWithEmail(
        email: email.trim().toLowerCase(),
        password: password,
      );
      if (_disposed || session != _sessionRevision) {
        return 'Session changed. Please sign in again.';
      }
      _currentUser = user;
      if (!isBatStateUEmail(user.email)) {
        await logout();
        return 'Access Denied: Only users with a valid @g.batstate-u.edu.ph email address can log in.';
      }
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

  /// Signs the user out and clears local state.
  Future<void> logout() async {
    ++_sessionRevision;
    ++_authRevision;
    await _authService.logout();
    _currentUser = null;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_authRevision;
    _authSubscription?.cancel();
    super.dispose();
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
