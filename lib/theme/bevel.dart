import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Win95-style "Machined Bevel" decorations per DESIGN.md.
class Bevel {
  /// Raised bevel: top/left light, bottom/right dark.
  static BoxDecoration raised({Color? fill}) {
    return BoxDecoration(
      color: fill ?? AppColors.surfaceContainerHigh,
      border: const Border(
        top: BorderSide(color: AppColors.surfaceContainerLowest, width: 2),
        left: BorderSide(color: AppColors.surfaceContainerLowest, width: 2),
        bottom: BorderSide(color: AppColors.outlineVariant, width: 2),
        right: BorderSide(color: AppColors.outlineVariant, width: 2),
      ),
    );
  }

  /// Sunken bevel: top/left dark, bottom/right light.
  static BoxDecoration sunken({Color? fill}) {
    return BoxDecoration(
      color: fill ?? AppColors.surfaceContainerLowest,
      border: const Border(
        top: BorderSide(color: AppColors.outlineVariant, width: 2),
        left: BorderSide(color: AppColors.outlineVariant, width: 2),
        bottom: BorderSide(color: AppColors.surfaceContainerLowest, width: 2),
        right: BorderSide(color: AppColors.surfaceContainerLowest, width: 2),
      ),
    );
  }

  /// Ghost border: subtle outline for containers on complex backgrounds.
  static BoxDecoration ghost({Color? fill, double opacity = 0.15}) {
    return BoxDecoration(
      color: fill,
      border: Border.all(
        color: AppColors.outlineVariant.withValues(alpha: opacity),
        width: 1,
      ),
    );
  }
}
