import 'package:flutter/material.dart';

/// The shared FindIt BSU search-pin brand mark.
class BrandLogo extends StatelessWidget {
  final double size;
  const BrandLogo({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .27),
    child: Image.asset(
      'assets/branding/findit-logo.png',
      width: size,
      height: size,
      semanticLabel: 'FindIt BSU logo',
      filterQuality: FilterQuality.high,
    ),
  );
}
