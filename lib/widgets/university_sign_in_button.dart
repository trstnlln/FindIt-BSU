import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A single action for university account registration and returning sign-in.
class UniversitySignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const UniversitySignInButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb &&
        defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.school_outlined, size: 22),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Continue with university Google account',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your university email and Google account name fill in automatically.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
