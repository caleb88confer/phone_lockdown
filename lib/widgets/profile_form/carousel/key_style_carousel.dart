import 'package:flutter/material.dart';
import '../../../customization/key_catalog.dart';
import '../../sprite_sheet.dart';
import 'sprite_carousel.dart';

class KeyStyleCarousel extends StatelessWidget {
  static const Duration _spriteAnimationDuration = Duration(milliseconds: 1200);

  final String selectedStyleId;
  final String selectedColorId;
  final ValueChanged<String> onStyleChanged;

  const KeyStyleCarousel({
    super.key,
    required this.selectedStyleId,
    required this.selectedColorId,
    required this.onStyleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedIndex =
        kKeyCatalog.indexWhere((s) => s.id == selectedStyleId).clamp(0, kKeyCatalog.length - 1);

    return SpriteCarousel<KeyStyle>(
      items: kKeyCatalog,
      selectedIndex: selectedIndex,
      onSelectedChanged: (i) => onStyleChanged(kKeyCatalog[i].id),
      centerSize: 64,
      sideSize: 44,
      edgeSize: 28,
      cellGap: 8,
      peekCount: 5,
      infiniteLoop: true,
      centerBob: true,
      bobAmplitude: 4,
      bobPeriod: const Duration(milliseconds: 1400),
      sideSquish: true,
      sideFade: true,
      centerBevel: false,
      itemBuilder: (context, style, centerness) {
        final renderColorId = renderColorIdFor(style, selectedColorId);
        final assetPath = style.spritesheetPath(renderColorId);
        if (style.animated) {
          return AnimatedSprite(
            key: ValueKey('keycar-${style.id}-$renderColorId'),
            assetPath: assetPath,
            frameWidth: style.frameWidth,
            frameHeight: style.frameHeight,
            frameCount: style.frameCount,
            startFrame: 0,
            endFrame: style.frameCount - 1,
            duration: _spriteAnimationDuration,
            loop: true,
            size: 44,
          );
        }
        return SpriteFrame(
          key: ValueKey('keycar-${style.id}-$renderColorId-static'),
          assetPath: assetPath,
          frameWidth: style.frameWidth,
          frameHeight: style.frameHeight,
          frameIndex: 0,
          size: 44,
        );
      },
    );
  }
}
