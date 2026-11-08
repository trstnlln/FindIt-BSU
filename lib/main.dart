import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'services/backend_setup.dart';
import 'providers/auth_provider.dart';
import 'providers/item_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'widgets/brand_logo.dart';
import 'services/crash_reporting.dart';
import 'screens/auth/verify_email_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppBootstrap());
}

/// Keep startup failures recoverable instead of leaving a blank launch screen.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});
  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late Future<FirebaseApp> _initialization;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _initialize() {
    _initialization = BackendSetup.initialize()
        .timeout(const Duration(seconds: 25))
        .then((app) async {
          try {
            await CrashReporting.initialize();
          } catch (_) {
            /* Telemetry must not block account access. */
          }
          return app;
        });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<FirebaseApp>(
    future: _initialization,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => ItemProvider()),
          ],
          child: const FindItApp(),
        );
      }
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BrandLogo(size: 80),
                    const SizedBox(height: 24),
                    Text(
                      snapshot.hasError
                          ? 'Let’s try that again'
                          : 'Finding our way…',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (snapshot.hasError) ...[
                      const Text(
                        'We couldn’t connect to FindIt BSU. Check your connection and try again.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => setState(_initialize),
                        child: const Text('Try again'),
                      ),
                    ] else
                      const CircularProgressIndicator(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class FindItApp extends StatelessWidget {
  const FindItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FindIt BSU',
      debugShowCheckedModeBanner: false,

      theme: AppTheme.light,
      // Firebase's web emulator adds a fixed footer. Reserve space so it
      // cannot cover message inputs or send buttons in local testing.
      builder: (context, child) => BackendSetup.useEmulators
          ? Padding(
              padding: EdgeInsets.only(bottom: kIsWeb ? 64 : 0),
              child: Banner(
                message: 'LOCAL TEST',
                location: BannerLocation.topEnd,
                child: child!,
              ),
            )
          : child!,

      // ── Auth Gate ────────────────────────────────────────────────────────
      // Watches AuthProvider to decide which screen to show.
      // Firebase Auth persists the session, so _onAuthStateChanged in
      // AuthProvider automatically restores the user on every app launch.
      home: const _AuthGate(),
    );
  }
}

/// Listens to [AuthProvider] and routes to [LoginScreen] or [HomeScreen].
/// Displays a loading spinner while the initial auth state is being resolved.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // Show a splash/loading screen ONLY on cold start while checking saved session.
    // This ensures LoginScreen is not destroyed/cleared during login submissions.
    if (authProvider.isInitialLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (authProvider.isLoggedIn) {
      if (!authProvider.isEmailVerified) return const VerifyEmailScreen();
      return const HomeScreen();
    }

    return const LoginScreen();
  }
}
