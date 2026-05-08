import 'package:flutter/material.dart';
import '../customization/key_catalog.dart';
import 'sprite_sheet.dart';

class KeyDisplay extends StatelessWidget {
  final KeyStyle style;
  final KeyColorOption color;
  final double size;

  const KeyDisplay({
    super.key,
    required this.style,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final assetPath = style.spritesheetPath(color.id);
    final renderSize = size * style.displayScale;

    if (!style.animated) {
      return SpriteFrame(
        assetPath: assetPath,
        frameWidth: style.frameWidth,
        frameHeight: style.frameHeight,
        frameIndex: 0,
        size: renderSize,
      );
    }

    return AnimatedSprite(
      assetPath: assetPath,
      frameWidth: style.frameWidth,
      frameHeight: style.frameHeight,
      frameCount: style.frameCount,
      startFrame: 0,
      endFrame: style.frameCount - 1,
      duration: style.durationFor(style.frameCount),
      loop: true,
      size: renderSize,
    );
  }
}
