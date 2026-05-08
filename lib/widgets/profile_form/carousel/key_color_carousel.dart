import 'package:flutter/material.dart';
import '../../../customization/key_catalog.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/bevel.dart';
import '../../sprite_sheet.dart';
import 'sprite_carousel.dart';

class KeyColorCarousel extends StatelessWidget {
  final String selectedStyleId;
  final String selectedColorId;
  final ValueChanged<String> onColorChanged;

  const KeyColorCarousel({
    super.key,
    required this.selectedStyleId,
    required this.selectedColorId,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    final style = keyStyleById(selectedStyleId);
    final colors = style.colors;
    final selectedIndex = colorCenterIndex(style, selectedColorId);

    return SpriteCarousel<KeyColorOption>(
      items: colors,
      selectedIndex: selectedIndex,
      onSelectedChanged: (i) => onColorChanged(colors[i].id),
      centerSize: 44,
      sideSize: 44,
      edgeSize: 44,
      cellGap: 12,
      peekCount: 3,
      infiniteLoop: false,
      centerBob: false,
      bobAmplitude: 0,
      bobPeriod: const Duration(milliseconds: 1),
      sideSquish: false,
      sideFade: false,
      centerBevel: true,
      itemBuilder: (context, color, centerness, targetSize) {
        final isCenter = centerness > 0.5;
        return Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: isCenter
              ? Bevel.raised(fill: AppColors.surfaceContainerHigh)
              : Bevel.ghost(
                  fill: AppColors.surfaceContainerLow,
                  opacity: 0.4,
                ),
          child: SpriteFrame(
            assetPath: style.spritesheetPath(color.id),
            frameWidth: style.frameWidth,
            frameHeight: style.frameHeight,
            frameIndex: 0,
            size: 36 * style.displayScale,
          ),
        );
      },
    );
  }
}
