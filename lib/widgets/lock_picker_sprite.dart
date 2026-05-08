import 'package:flutter/material.dart';
import '../customization/lock_catalog.dart';
import 'sprite_sheet.dart';

class LockPickerSprite extends StatelessWidget {
  final LockStyle style;
  final LockColorOption color;
  final double size;
  final bool playing;

  const LockPickerSprite({
    super.key,
    required this.style,
    required this.color,
    required this.size,
    required this.playing,
  });

  @override
  Widget build(BuildContext context) {
    final assetPath = style.spritesheetPath(color.id);
    final renderSize = size * style.displayScale;

    final Widget sprite;
    if (playing) {
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
    } else {
      sprite = SpriteFrame(
        assetPath: assetPath,
        frameWidth: style.frameWidth,
        frameHeight: style.frameHeight,
        frameIndex: style.lockedFrame,
        size: renderSize,
      );
    }

    final dy = renderSize * style.centerOffsetY;
    if (dy == 0) return sprite;
    return Transform.translate(offset: Offset(0, dy), child: sprite);
  }
}
