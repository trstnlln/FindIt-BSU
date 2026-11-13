import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';
import '../models/university_account.dart';

import 'package:google_sign_in/google_sign_in.dart';

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
  bool _emailVerified = false;
  bool _approvedStaff = false;
  bool get hasCampusAccess =>
      _currentUser != null &&
      (isBatStateUEmail(_currentUser!.email) || _approvedStaff);
  bool get isEmailVerified => _emailVerified;
  bool _isLoading = false;
  bool _disposed = false;
  bool _interactiveSignInInProgress = false;
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
        if (_interactiveSignInInProgress) return;
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
    _emailVerified = firebaseUser?.emailVerified ?? false;
    if (firebaseUser == null) {
      _approvedStaff = false;
      ++_sessionRevision;
      _currentUser = null;
    } else {
      final email = firebaseUser.email ?? '';
      // External staff identities require a trusted administrator-issued claim.
      final approvedStaff = await _authService.isApprovedStaff(
        firebaseUser.uid,
      );
      if (_disposed || revision != _authRevision) return;
      _approvedStaff = approvedStaff;
      if (!isBatStateUEmail(email) && !approvedStaff) {
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
  static bool isBatStateUEmail(String email) =>
      UniversityAccount.isCampusEmail(email);

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
      _emailVerified = _authService.currentFirebaseUser?.emailVerified ?? false;
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
  /// or null on success. Staff approval is checked after authentication.
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim())) {
      return 'Enter a valid email address.';
    }
    if (_isLoading) return 'Please wait for the current request to finish.';
    final session = _sessionRevision;
    ++_authRevision;
    _interactiveSignInInProgress = true;
    _setLoading(true);
    try {
      final user = await _authService.loginWithEmail(
        email: email.trim().toLowerCase(),
        password: password,
      );
      if (_disposed || session != _sessionRevision) {
        return 'Session changed. Please sign in again.';
      }
      final approvedStaff = await _authService.isApprovedStaff(user.id);
      if (_disposed || session != _sessionRevision) {
        return 'Session changed. Please sign in again.';
      }
      _approvedStaff = approvedStaff;
      if (!isBatStateUEmail(user.email) && !approvedStaff) {
        await logout();
        return 'Use a university account or ask an administrator to approve your staff email.';
      }
      _emailVerified = _authService.currentFirebaseUser?.emailVerified ?? false;
      _currentUser = user;
      _isInitialLoading = false;
      notifyListeners();
      return null; // null = success
    } on FirebaseAuthException catch (e) {
      return _mapFirebaseError(e.code);
    } catch (e) {
      return 'Login failed: ${e.toString().replaceAll('Exception: ', '')}';
    } finally {
      _interactiveSignInInProgress = false;
      _setLoading(false);
    }
  }

  /// Registration and login share one verified Google flow. No typed name,
  /// password, or user-selected role is submitted by the Google button.
  Future<String?> signInWithUniversityGoogle() async {
    if (_isLoading) return 'Please wait for the current request to finish.';
    final session = _sessionRevision;
    ++_authRevision; // invalidate older profile reads
    _interactiveSignInInProgress = true;
    _setLoading(true);
    try {
      final user = await _authService.signInWithUniversityGoogle();
      if (_disposed || session != _sessionRevision) {
        await _authService.logout();
        return 'Session changed. Please sign in again.';
      }
      if ((!isBatStateUEmail(user.email) &&
              !await _authService.isApprovedStaff(user.id)) ||
          user.name.trim().isEmpty) {
        await _authService.logout();
        _currentUser = null;
        return 'Use a university Google account or an approved staff account.';
      }
      _approvedStaff = await _authService.isApprovedStaff(user.id);
      if (_disposed || session != _sessionRevision) {
        return 'Session changed. Please sign in again.';
      }
      _currentUser = user;
      _emailVerified = true;
      _isInitialLoading = false;
      return null;
    } on UniversityAccountException catch (error) {
      return error.message;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      return 'University sign-in is unavailable right now. Please try again or use email and password.';
    } on FirebaseAuthException catch (error) {
      if (error.code == 'popup-closed-by-user' ||
          error.code == 'cancelled-popup-request') {
        return null;
      }
      return _mapFirebaseError(error.code);
    } catch (_) {
      return 'We couldn’t finish university sign-in. Check your connection and try again.';
    } finally {
      _interactiveSignInInProgress = false;
      _setLoading(false);
    }
  }

  Future<String?> sendVerificationEmail() async {
    try {
      await _authService.sendVerificationEmail();
      return null;
    } on FirebaseAuthException catch (error) {
      return _mapFirebaseError(error.code);
    } catch (_) {
      return 'Could not send the email. Check your connection and try again.';
    }
  }

  Future<String?> refreshVerification() async {
    try {
      final user = await _authService.refreshIdentity();
      await _onAuthStateChanged(user);
      return _emailVerified
          ? null
          : 'Your email is not verified yet. Open the link in your university inbox first.';
    } catch (_) {
      return 'Could not check verification. Please try again.';
    }
  }

  Future<String?> resetPassword(String email) async {
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim())) {
      return 'Enter your email address first.';
    }
    try {
      await _authService.resetPassword(email);
      return null;
    } catch (_) {
      return 'Could not send the reset email. Please try again.';
    }
  }

  /// Signs the user out and clears local state.
  Future<void> logout() async {
    ++_sessionRevision;
    ++_authRevision;
    await _authService.logout();
    _currentUser = null;
    _emailVerified = false;
    _approvedStaff = false;
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
      case 'university-sign-in-unavailable':
        return 'This sign-in method is unavailable right now. Please use another sign-in option.';
      case 'popup-blocked':
        return 'Allow the sign-in popup in your browser and try again.';
      case 'account-exists-with-different-credential':
        return 'This email already uses another sign-in method. Sign in with your existing method first.';
      case 'unauthorized-domain':
        return 'University sign-in is unavailable on this website. Please use email and password.';
      case 'channel-error':
        return 'Please enter both your email and password.';
      default:
        return 'Authentication error ($code). Please try again.';
    }
  }
}
