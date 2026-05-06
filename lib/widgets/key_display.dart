import 'package:flutter/material.dart';
import '../customization/key_catalog.dart';
import 'sprite_sheet.dart';

class KeyDisplay extends StatelessWidget {
  final KeyStyle style;
  final KeyColorOption color;
  final double size;
  final Duration loopDuration;

  const KeyDisplay({
    super.key,
    required this.style,
    required this.color,
    required this.size,
    this.loopDuration = const Duration(milliseconds: 1200),
  });

  @override
  Widget build(BuildContext context) {
    final assetPath = style.spritesheetPath(color.id);

    if (!style.animated) {
      return SpriteFrame(
        assetPath: assetPath,
        frameWidth: style.frameWidth,
        frameHeight: style.frameHeight,
        frameIndex: 0,
        size: size,
      );
    }

    return AnimatedSprite(
      assetPath: assetPath,
      frameWidth: style.frameWidth,
      frameHeight: style.frameHeight,
      frameCount: style.frameCount,
      startFrame: 0,
      endFrame: style.frameCount - 1,
      duration: loopDuration,
      loop: true,
      size: size,
    );
  }
}
