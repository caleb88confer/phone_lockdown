import 'package:flutter/material.dart';
import '../customization/lock_catalog.dart';
import 'sprite_sheet.dart';

class LockPickerSprite extends StatefulWidget {
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
  State<LockPickerSprite> createState() => _LockPickerSpriteState();
}

class _LockPickerSpriteState extends State<LockPickerSprite> {
  // True when playing was just turned off and we're letting the current loop
  // run to completion so the lock returns to its closed pose smoothly.
  bool _finishing = false;

  @override
  void didUpdateWidget(LockPickerSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing && !widget.playing) {
      setState(() => _finishing = true);
    } else if (!oldWidget.playing && widget.playing && _finishing) {
      setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final assetPath = widget.style.spritesheetPath(widget.color.id);
    final renderSize = widget.size * widget.style.displayScale;

    final Widget sprite;
    if (widget.playing || _finishing) {
      sprite = AnimatedSprite(
        assetPath: assetPath,
        frameWidth: widget.style.frameWidth,
        frameHeight: widget.style.frameHeight,
        frameCount: widget.style.frameCount,
        startFrame: 0,
        endFrame: widget.style.frameCount - 1,
        duration: widget.style.durationFor(widget.style.frameCount),
        loop: widget.playing,
        onComplete: () {
          if (mounted && _finishing) setState(() => _finishing = false);
        },
        size: renderSize,
      );
    } else {
      sprite = SpriteFrame(
        assetPath: assetPath,
        frameWidth: widget.style.frameWidth,
        frameHeight: widget.style.frameHeight,
        frameIndex: widget.style.lockedFrame,
        size: renderSize,
      );
    }

    final dy = renderSize * widget.style.centerOffsetY;
    if (dy == 0) return sprite;
    return Transform.translate(offset: Offset(0, dy), child: sprite);
  }
}
