import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/bevel.dart';

/// Renders [child] as a flat dark silhouette with a small lock-badge in the
/// top-right corner. Used wherever a locked unlock-order item is shown —
/// style carousels (chunk 7) and palette rows (chunk 7).
class LockedSpriteOverlay extends StatelessWidget {
  final Widget child;
  final double badgeIconSize;
  // When true, paint the silhouette fully opaque black instead of the muted
  // on-surface tint. Used by the key carousel so locked keys read as a single
  // black shape rather than a darkened version of their own sprite.
  final bool solidBlack;

  const LockedSpriteOverlay({
    super.key,
    required this.child,
    this.badgeIconSize = 12,
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
            child: Icon(
              Icons.lock,
              size: badgeIconSize,
              color: AppColors.outline,
            ),
          ),
        ),
      ],
    );
  }
}
