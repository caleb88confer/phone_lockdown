import 'package:flutter/material.dart';
import '../customization/key_catalog.dart';
import 'sprite_sheet.dart';

class KeyDisplay extends StatelessWidget {
  final KeyStyle style;
  final KeyColorOption color;
  final double size;
  // When non-null, render this static frame instead of animating.
  final int? staticFrame;

  const KeyDisplay({
    super.key,
    required this.style,
    required this.color,
    required this.size,
    this.staticFrame,
  });

  @override
  Widget build(BuildContext context) {
    final assetPath = style.spritesheetPath(color.id);
    final renderSize = size * style.displayScale;

    final Widget sprite;
    if (staticFrame != null || !style.animated) {
      sprite = SpriteFrame(
        assetPath: assetPath,
        frameWidth: style.frameWidth,
        frameHeight: style.frameHeight,
        frameIndex: staticFrame ?? 0,
        size: renderSize,
      );
    } else {
      sprite = AnimatedSprite(
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

    final dy = renderSize * style.centerOffsetY;
    if (dy == 0) return sprite;
    return Transform.translate(offset: Offset(0, dy), child: sprite);
  }
}
