import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/university_sign_in_button.dart';
import 'register_screen.dart';
import '../../widgets/brand_logo.dart';

/// University Google sign-in with an optional email/password fallback.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _showEmailForm = !UniversitySignInButton.isSupported;
  String? _errorMessage;

  // Animation controller for the logo entrance
  late final AnimationController _animController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _animController.value = 1;
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ─── Actions ────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (context.read<AuthProvider>().isLoading) return;
    // Hide keyboard
    FocusScope.of(context).unfocus();

    // Clear previous error
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final error = await authProvider.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (error != null && mounted) {
      setState(() => _errorMessage = error);
    }
  }

  Future<void> _resetPassword() async {
    final error = await context.read<AuthProvider>().resetPassword(
      _emailController.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ?? 'If an account exists, a reset link has been sent. Check your email inbox.',
        ),
      ),
    );
  }

  void _goToRegister() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const RegisterScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                  ),
              child: child,
            ),
      ),
    );
  }

  Future<void> _continueWithUniversityAccount() async {
    FocusScope.of(context).unfocus();
    setState(() => _errorMessage = null);
    final auth = context.read<AuthProvider>();
    final error = await auth.signInWithUniversityGoogle();
    if (!mounted) return;
    if (error != null) {
      setState(() => _errorMessage = error);
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLoading = context.watch<AuthProvider>().isLoading;
    final compact =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.sizeOf(context).height < 760;
    final verticalPadding = compact ? 20.0 : 32.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: verticalPadding,
            ),
            child: FadeTransition(
              opacity: _fadeIn,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 480,
                    minHeight: (viewport.maxHeight - verticalPadding * 2).clamp(
                      0.0,
                      double.infinity,
                    ),
                  ),
                  child: SlideTransition(
                    position: _slideUp,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: compact ? 0 : 12),

                            // ── Logo & Branding ──────────────────────────────────
                            _buildLogo(colorScheme, compact: compact),
                            SizedBox(height: compact ? 20 : 24),
                            Text(
                              'Lost things.',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontSize: 32,
                                height: 1.12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.2,
                              ),
                            ),
                            Text(
                              'Found together.',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontSize: 32,
                                height: 1.12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.2,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Your campus community for finding what matters.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            SizedBox(height: compact ? 20 : 28),

                            // ── Form Card ────────────────────────────────────────
                            Card(
                              elevation: 0,
                              color: Colors.white,
                              child: Padding(
                                padding: EdgeInsets.all(compact ? 18 : 20),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'Welcome, Spartan.',
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.onSurface,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Use your university account or an approved staff account.',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                      SizedBox(height: compact ? 16 : 24),

                                      UniversitySignInButton(
                                        primary: true,
                                        isLoading: isLoading,
                                        onPressed: isLoading
                                            ? null
                                            : _continueWithUniversityAccount,
                                      ),
                                      SizedBox(height: compact ? 8 : 20),
                                      if (_errorMessage != null) ...[
                                        Semantics(
                                          liveRegion: true,
                                          child: _buildErrorBanner(
                                            _errorMessage!,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                      if (UniversitySignInButton.isSupported)
                                        TextButton(
                                          onPressed: isLoading
                                              ? null
                                              : () {
                                                  FocusScope.of(context)
                                                      .unfocus();
                                                  setState(() {
                                                    _showEmailForm =
                                                        !_showEmailForm;
                                                    _errorMessage = null;
                                                  });
                                                },
                                          child: Text(
                                            _showEmailForm
                                                ? 'Use university Google instead'
                                                : 'Sign in with email instead',
                                          ),
                                        ),
                                      if (_showEmailForm) ...[
                                        const SizedBox(height: 20),
                                        Text(
                                          'Use your FindIt-BSU password, not your Google password.',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                        const SizedBox(height: 16),

                                        // Email field
                                        _buildEmailField(colorScheme),
                                        const SizedBox(height: 16),

                                        // Password field
                                        _buildPasswordField(colorScheme),
                                        const SizedBox(height: 12),

                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: isLoading
                                                ? null
                                                : _resetPassword,
                                            child: const Text(
                                              'Forgot password?',
                                            ),
                                          ),
                                        ),
                                        // Login button
                                        _buildLoginButton(
                                          isLoading,
                                          colorScheme,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            if (_showEmailForm) const SizedBox(height: 20),

                            if (_showEmailForm)
                              // ── Register Link ────────────────────────────────────
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    "Don't have an account? ",
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: isLoading ? null : _goToRegister,
                                    child: Text(
                                      'Register',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        Padding(
                          padding: EdgeInsets.only(top: compact ? 20 : 24),
                          child: _RecoveryGuide(compact: compact),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Widget Helpers ─────────────────────────────────────────────────────

  Widget _buildLogo(ColorScheme colorScheme, {required bool compact}) {
    return Row(
      children: [
        BrandLogo(size: compact ? 48 : 52),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FindIt BSU',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.primary,
                  letterSpacing: -.7,
                ),
              ),
              Text(
                'ALANGILAN CAMPUS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField(ColorScheme colorScheme) {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      autofillHints: const [AutofillHints.email],
      decoration: InputDecoration(
        labelText: 'Email address',
        hintText: 'Your email address',
        prefixIcon: const Icon(Icons.email_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your email.';
        }
        final email = value.trim().toLowerCase();
        final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
        if (!emailRegex.hasMatch(email)) {
          return 'Please enter a valid email address.';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField(ColorScheme colorScheme) {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      autofillHints: const [AutofillHints.password],
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(Icons.lock_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          tooltip: _obscurePassword ? 'Show password' : 'Hide password',
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password.';
        }
        return null;
      },
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton(bool isLoading, ColorScheme colorScheme) {
    return FilledButton(
      onPressed: isLoading ? null : _submit,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : const Text(
              'Log In',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
    );
  }
}

/// A short introduction to the recovery process before students sign in.
class _RecoveryGuide extends StatelessWidget {
  final bool compact;
  const _RecoveryGuide({required this.compact});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A little help goes a long way.',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 4),
          Text(
            'Three steps to a happy reunion.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth < 240 ||
                  MediaQuery.textScalerOf(context).scale(12) > 18;
              final steps = [
                _step(
                  context,
                  Icons.search_rounded,
                  'Find',
                  'Browse reports',
                  stacked,
                ),
                _step(
                  context,
                  Icons.verified_user_outlined,
                  'Verify',
                  'Show your proof',
                  stacked,
                ),
                _step(
                  context,
                  Icons.handshake_outlined,
                  'Reunite',
                  'Meet on campus',
                  stacked,
                ),
              ];
              if (stacked) {
                return Column(
                  children: [
                    for (var i = 0; i < steps.length; i++) ...[
                      if (i > 0) const SizedBox(height: 16),
                      steps[i],
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < steps.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: steps[i]),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _step(
    BuildContext context,
    IconData icon,
    String title,
    String description,
    bool stacked,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final symbol = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: scheme.primary),
    );
    final text = Column(
      crossAxisAlignment: stacked
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: scheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          textAlign: stacked ? TextAlign.start : TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            height: 1.4,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    if (stacked) {
      return Row(
        children: [
          symbol,
          const SizedBox(width: 12),
          Expanded(child: text),
        ],
      );
    }
    return Column(children: [symbol, const SizedBox(height: 8), text]);
  }
}
