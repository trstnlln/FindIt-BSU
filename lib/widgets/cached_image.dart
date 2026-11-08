import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Performance-optimized network image widget that caches photos locally
/// to prevent repeated network requests, with placeholder and error fallback.
class CachedImage extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final double borderRadius;
  final Widget? fallbackWidget;
  final BoxFit fit;

  const CachedImage({
    super.key,
    required this.imageUrl,
    this.width = 78,
    this.height = 78,
    this.borderRadius = 12,
    this.fallbackWidget,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (imageUrl == null || imageUrl!.trim().isEmpty) {
      return fallbackWidget ?? _buildPlaceholder(colorScheme);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) =>
            fallbackWidget ?? _buildPlaceholder(colorScheme),
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: width * 0.4,
          color: colorScheme.primary,
        ),
      ),
    );
  }
}

