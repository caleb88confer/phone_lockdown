import 'package:flutter/material.dart';
import '../../customization/lock_catalog.dart';
import '../../theme/app_colors.dart';
import '../../theme/bevel.dart';
import '../sprite_sheet.dart';

class LockStyleColorPicker extends StatelessWidget {
  static const Duration _animationDuration = Duration(milliseconds: 1200);

  final String selectedStyleId;
  final String selectedColorId;
  final ValueChanged<String> onStyleChanged;
  final ValueChanged<String> onColorChanged;

  const LockStyleColorPicker({
    super.key,
    required this.selectedStyleId,
    required this.selectedColorId,
    required this.onStyleChanged,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedStyle = lockStyleById(selectedStyleId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LOCK',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kLockCatalog.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final style = kLockCatalog[i];
              final isSelected = style.id == selectedStyleId;
              final previewColor = style.colors.first;
              final assetPath = style.spritesheetPath(previewColor.id);
              return GestureDetector(
                onTap: () => onStyleChanged(style.id),
                child: Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: isSelected
                      ? Bevel.raised(fill: AppColors.surfaceContainerHigh)
                      : Bevel.ghost(
                          fill: AppColors.surfaceContainerLow,
                          opacity: 0.4,
                        ),
                  child: isSelected
                      ? AnimatedSprite(
                          key: ValueKey('lock-anim-${style.id}'),
                          assetPath: assetPath,
                          frameWidth: style.frameWidth,
                          frameHeight: style.frameHeight,
                          frameCount: style.frameCount,
                          startFrame: 0,
                          endFrame: style.frameCount - 1,
                          duration: _animationDuration,
                          loop: true,
                          size: 44,
                        )
                      : SpriteFrame(
                          assetPath: assetPath,
                          frameWidth: style.frameWidth,
                          frameHeight: style.frameHeight,
                          frameIndex: style.lockedFrame,
                          size: 44,
                        ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: selectedStyle.colors.map((c) {
            final isSelected = c.id == selectedColorId;
            return GestureDetector(
              onTap: () => onColorChanged(c.id),
              child: Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: isSelected
                    ? Bevel.raised(fill: AppColors.surfaceContainerHigh)
                    : Bevel.ghost(
                        fill: AppColors.surfaceContainerLow,
                        opacity: 0.4,
                      ),
                child: SpriteFrame(
                  assetPath: selectedStyle.spritesheetPath(c.id),
                  frameWidth: selectedStyle.frameWidth,
                  frameHeight: selectedStyle.frameHeight,
                  frameIndex: selectedStyle.lockedFrame,
                  size: 44,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
