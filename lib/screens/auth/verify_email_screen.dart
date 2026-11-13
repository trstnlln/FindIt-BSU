import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/brand_logo.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});
  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _busy = false;
  DateTime? _sent;
  String? _message;
  Future<void> _check() async {
    setState(() => _busy = true);
    final message = await context.read<AuthProvider>().refreshVerification();
    if (mounted) {
      setState(() {
        _message = message;
        _busy = false;
      });
    }
  }

  Future<void> _resend() async {
    if (_sent != null && DateTime.now().difference(_sent!).inSeconds < 60) {
      setState(
        () =>
            _message = 'Please wait a minute before requesting another email.',
      );
      return;
    }
    setState(() => _busy = true);
    final error = await context.read<AuthProvider>().sendVerificationEmail();
    if (mounted) {
      setState(() {
        _busy = false;
        _message =
            error ??
            'Verification email sent. Check your inbox and spam folder.';
        if (error == null) _sent = DateTime.now();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandLogo(size: 80),
                const SizedBox(height: 24),
                Text(
                  'Verify your email',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Open the verification link sent to ${context.watch<AuthProvider>().currentUser?.email ?? 'your inbox'}. Then return here to continue.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (_message != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(_message!, textAlign: TextAlign.center),
                  ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _check,
                  child: Text(_busy ? 'Checking…' : 'I’ve verified my email'),
                ),
                TextButton(
                  onPressed: _busy ? null : _resend,
                  child: const Text('Resend verification email'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => context.read<AuthProvider>().logout(),
                  child: const Text('Use another account'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
