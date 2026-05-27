import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/bevel.dart';

/// Paints [child] as a flat silhouette to mark it as locked — either pure
/// black ([solidBlack] true, used by the style carousels) or the muted
/// on-surface tint (the default, used by palette swatches). The shape is
/// preserved; only the fill is recoloured. A small lock-icon badge sits in
/// the top-right corner so the locked state reads at a glance.
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
    final silhouette = solidBlack
        ? const Color(0xFF000000)
        : AppColors.onSurface.withValues(alpha: 0.45);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(silhouette, BlendMode.srcIn),
          child: child,
        ),
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: Bevel.raised(fill: AppColors.surfaceContainerHigh),
            child: const Icon(
              Icons.lock,
              size: 12,
              color: AppColors.outline,
            ),
          ),
        ),
      ],
    );
  }
}
