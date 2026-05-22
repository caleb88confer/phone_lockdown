import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A one-shot pixel-art burst: small 4x2 pixel shards fire out from the centre,
/// spin as they travel, decelerate, then fade. Plays once when first built, so
/// mount it at the moment you want the explosion (e.g. when a lock lands).
class PixelBurst extends StatefulWidget {
  /// Shard colours, chosen at random per shard. Pass the lock's swatch + white.
  final List<Color> colors;
  final int count;

  /// Base distance (logical px) a shard travels; jittered per shard.
  final double travel;

  /// Logical px per sprite pixel — each shard is 4x2 of these.
  final double shardPixel;

  /// Maximum full rotations a shard makes over its flight (either direction).
  final double spinTurns;

  final Duration duration;
  final int seed;

  const PixelBurst({
    super.key,
    required this.colors,
    this.count = 30,
    this.travel = 160,
    this.shardPixel = 4,
    this.spinTurns = 2,
    this.duration = const Duration(milliseconds: 600),
    this.seed = 0,
  });

  @override
  State<PixelBurst> createState() => _PixelBurstState();
}

class _PixelBurstState extends State<PixelBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Shard> _shards;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(widget.seed);
    final slice = 2 * math.pi / widget.count;
    _shards = List.generate(widget.count, (i) {
      // Spread directions evenly around the circle, then jitter within a slice
      // so the burst reads as radial but not mechanically regular.
      final angle = i * slice + (rng.nextDouble() - 0.5) * slice;
      return _Shard(
        angle: angle,
        distance: widget.travel * (0.55 + rng.nextDouble() * 0.65),
        rotation: rng.nextDouble() * 2 * math.pi,
        spin: (rng.nextDouble() * 2 - 1) * widget.spinTurns * 2 * math.pi,
        color: widget.colors[rng.nextInt(widget.colors.length)],
        sizeJitter: 0.8 + rng.nextDouble() * 0.5,
      );
    });
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, _) => CustomPaint(
          size: Size.infinite,
          painter: _BurstPainter(
            shards: _shards,
            t: _controller.value,
            shardPixel: widget.shardPixel,
          ),
        ),
      ),
    );
  }
}

class _Shard {
  final double angle; // travel direction
  final double distance; // max travel distance
  final double rotation; // initial rotation
  final double spin; // total rotation added over the burst
  final Color color;
  final double sizeJitter;

  const _Shard({
    required this.angle,
    required this.distance,
    required this.rotation,
    required this.spin,
    required this.color,
    required this.sizeJitter,
  });
}

class _BurstPainter extends CustomPainter {
  final List<_Shard> shards;
  final double t; // 0..1 progress
  final double shardPixel;

  _BurstPainter({
    required this.shards,
    required this.t,
    required this.shardPixel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1.0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final eased = Curves.easeOutCubic.transform(t); // fast out, then settle
    // Hold full opacity, then fade over the last 35%.
    final fade = t < 0.65 ? 1.0 : (1 - (t - 0.65) / 0.35).clamp(0.0, 1.0);

    for (final s in shards) {
      final d = s.distance * eased;
      final pos = center + Offset(math.cos(s.angle), math.sin(s.angle)) * d;
      final rot = s.rotation + s.spin * t;
      final w = 4 * shardPixel * s.sizeJitter;
      final h = 2 * shardPixel;

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(rot);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: w, height: h),
        Paint()
          ..color = s.color.withValues(alpha: fade)
          ..isAntiAlias = false,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}
