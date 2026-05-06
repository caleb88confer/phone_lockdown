import 'package:flutter/material.dart';
import '../customization/lock_catalog.dart';
import 'sprite_sheet.dart';

class LockDisplay extends StatefulWidget {
  final LockStyle style;
  final LockColorOption color;
  final bool isBlocking;
  final double size;
  final Duration transitionDuration;

  const LockDisplay({
    super.key,
    required this.style,
    required this.color,
    required this.isBlocking,
    required this.size,
    this.transitionDuration = const Duration(milliseconds: 350),
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

    if (_animating) {
      return AnimatedSprite(
        assetPath: assetPath,
        frameWidth: s.frameWidth,
        frameHeight: s.frameHeight,
        frameCount: s.frameCount,
        startFrame: _startFrame,
        endFrame: _endFrame,
        duration: widget.transitionDuration,
        size: widget.size,
        onComplete: () {
          if (mounted) setState(() => _animating = false);
        },
      );
    }

    final restingFrame =
        widget.isBlocking ? s.lockedFrame : s.unlockedFrame;
    return SpriteFrame(
      assetPath: assetPath,
      frameWidth: s.frameWidth,
      frameHeight: s.frameHeight,
      frameIndex: restingFrame,
      size: widget.size,
    );
  }
}
