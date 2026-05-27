import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Paints [child] as a flat silhouette to mark it as locked — either pure
/// black ([solidBlack] true, used by the style carousels) or the muted
/// on-surface tint (the default, used by palette swatches). The shape is
/// preserved; only the fill is recoloured.
class LockedSpriteOverlay extends StatelessWidget {
  final Widget child;
  final bool solidBlack;

  const LockedSpriteOverlay({
    super.key,
    required this.child,
    this.solidBlack = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = solidBlack
        ? const Color(0xFF000000)
        : AppColors.onSurface.withValues(alpha: 0.45);
    return ColorFiltered(
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      child: child,
    );
  }
}
