import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Wraps [child] in a vertical sine-wave bob — same pattern used by the
/// customization carousels. Pixel-rounds the offset to keep pixel art crisp.
class BobbingSprite extends StatefulWidget {
  final Widget child;
  final double amplitude;
  final Duration period;

  const BobbingSprite({
    super.key,
    required this.child,
    this.amplitude = 4,
    this.period = const Duration(milliseconds: 1400),
  });

  @override
  State<BobbingSprite> createState() => _BobbingSpriteState();
}

class _BobbingSpriteState extends State<BobbingSprite>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period);
    if (widget.amplitude > 0) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    } else if (!reduce && widget.amplitude > 0 && !_controller.isAnimating) {
      _controller.repeat();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final dy = widget.amplitude > 0
            ? (-widget.amplitude * math.sin(_controller.value * 2 * math.pi))
                  .roundToDouble()
            : 0.0;
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: widget.child,
    );
  }
}
