import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A single action for university account registration and returning sign-in.
class UniversitySignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool primary;
  const UniversitySignInButton({
    super.key,
    required this.onPressed,
    this.primary = false,
  });

  static bool get isSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    if (!isSupported) return const SizedBox.shrink();
    const label = Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'Continue with university Google account',
        textAlign: TextAlign.center,
      ),
    );
    const icon = Icon(Icons.school_outlined, size: 22);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (primary)
          FilledButton.icon(onPressed: onPressed, icon: icon, label: label)
        else
          OutlinedButton.icon(onPressed: onPressed, icon: icon, label: label),
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
