import 'package:flutter/material.dart';
import '../customization/lock_catalog.dart';
import 'sprite_sheet.dart';

class LockDisplay extends StatefulWidget {
  final LockStyle style;
  final LockColorOption color;
  final bool isBlocking;
  final double size;

  const LockDisplay({
    super.key,
    required this.style,
    required this.color,
    required this.isBlocking,
    required this.size,
  });

  @override
  State<LockDisplay> createState() => _LockDisplayState();
}

class _LockDisplayState extends State<LockDisplay> {
  bool _animating = false;
  late int _startFrame;
  late int _endFrame;

  @override
  void didUpdateWidget(LockDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isBlocking != widget.isBlocking ||
        oldWidget.style.id != widget.style.id ||
        oldWidget.color.id != widget.color.id) {
      _triggerTransition(oldWidget.isBlocking, widget.isBlocking);
    }
  }

  void _triggerTransition(bool from, bool to) {
    final s = widget.style;
    if (s.hasDistinctStates) {
      _startFrame = from ? s.lockedFrame : s.unlockedFrame;
      _endFrame = to ? s.lockedFrame : s.unlockedFrame;
    } else {
      _startFrame = 0;
      _endFrame = s.frameCount - 1;
    }
    setState(() => _animating = true);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.style;
    final assetPath = s.spritesheetPath(widget.color.id);
    final renderSize = widget.size * s.displayScale;

    final Widget sprite;
    if (_animating) {
      final framesPlayed = (_endFrame - _startFrame).abs() + 1;
      sprite = AnimatedSprite(
        assetPath: assetPath,
        frameWidth: s.frameWidth,
        frameHeight: s.frameHeight,
        frameCount: s.frameCount,
        startFrame: _startFrame,
        endFrame: _endFrame,
        duration: s.durationFor(framesPlayed),
        size: renderSize,
        onComplete: () {
          if (mounted) setState(() => _animating = false);
        },
      );
    } else {
      final restingFrame =
          widget.isBlocking ? s.lockedFrame : s.unlockedFrame;
      sprite = SpriteFrame(
        assetPath: assetPath,
        frameWidth: s.frameWidth,
        frameHeight: s.frameHeight,
        frameIndex: restingFrame,
        size: renderSize,
      );
    }

    final dy = renderSize * s.centerOffsetY;
    if (dy == 0) return sprite;
    return Transform.translate(offset: Offset(0, dy), child: sprite);
  }
}
