import 'package:flutter/material.dart';

/// Google's account picture, with a stable fallback while loading or offline.
class UserAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double size;
  const UserAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trimmedName = name.trim();
    final initial = trimmedName.isEmpty
        ? 'U'
        : trimmedName.characters.first.toUpperCase();
    final fallback = CircleAvatar(
      radius: size / 2,
      backgroundColor: scheme.primaryContainer,
      child: Text(
        initial,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontSize: size * .4,
          fontWeight: FontWeight.bold,
          color: scheme.primary,
        ),
      ),
    );
    final url = photoUrl?.trim();
    final uri = url == null ? null : Uri.tryParse(url);
    final hasPhoto =
        uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
    return Semantics(
      label: 'Profile picture',
      image: true,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: ClipOval(
          child: hasPhoto
              ? Image.network(
                  url!,
                  key: ValueKey(url),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  // Google images can be displayed on web even without canvas CORS access.
                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                  frameBuilder: (context, child, frame, synchronous) =>
                      frame == null ? fallback : child,
                  errorBuilder: (context, error, stack) => fallback,
                )
              : fallback,
        ),
      ),
    );
  }
}
