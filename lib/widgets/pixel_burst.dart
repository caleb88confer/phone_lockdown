import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A one-shot pixel-art burst: small rotating-shard sprites fire out from the
/// centre, spin (by cycling the sprite's frames) as they travel, decelerate,
/// then fade. Plays once when first built, so mount it at the moment you want
/// the explosion (e.g. when a lock lands).
///
/// The shard art lives in a horizontal sprite sheet of [_frameCount] square
/// frames showing one shard turning through a full rotation. The sheet is pure
/// white, so each shard is tinted to its swatch with a [BlendMode.modulate]
/// colour filter (white * colour = colour), which also carries the fade.
class PixelBurst extends StatefulWidget {
  /// Shard colours, chosen at random per shard. Pass the lock's swatch + white.
  final List<Color> colors;
  final int count;

  /// Base distance (logical px) a shard travels; jittered per shard.
  final double travel;

  /// Logical px per sprite pixel — each shard is [_frameSize] of these square.
  final double shardPixel;

  /// Full sprite-frame cycles (rotations) a shard makes over its flight; the
  /// direction is randomised per shard.
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

// Sprite sheet: a single shard turning through one rotation, laid out as
// [_frameCount] square [_frameSize]x[_frameSize] frames in a horizontal strip.
const String _shardAsset = 'assets/sprites/rotating_shard.png';
const int _frameSize = 5;
const int _frameCount = 8;

class _PixelBurstState extends State<PixelBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Shard> _shards;

  ui.Image? _image;
  ImageStream? _stream;
  ImageStreamListener? _listener;

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
        startFrame: rng.nextInt(_frameCount),
        // Total frames advanced over the flight, signed for spin direction.
        spinFrames:
            (rng.nextBool() ? 1 : -1) * widget.spinTurns * _frameCount,
        color: widget.colors[rng.nextInt(widget.colors.length)],
        sizeJitter: 0.8 + rng.nextDouble() * 0.5,
      );
    });
    _resolveImage();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
  }

  void _resolveImage() {
    final stream = const AssetImage(
      _shardAsset,
    ).resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      setState(() => _image = info.image);
    });
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  @override
  void dispose() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, _) => CustomPaint(
          size: Size.infinite,
          painter: _BurstPainter(
            image: image,
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
  final int startFrame; // initial sprite frame
  final double spinFrames; // total frames advanced over the burst (signed)
  final Color color;
  final double sizeJitter;

  const _Shard({
    required this.angle,
    required this.distance,
    required this.startFrame,
    required this.spinFrames,
    required this.color,
    required this.sizeJitter,
  });
}

class _BurstPainter extends CustomPainter {
  final ui.Image image;
  final List<_Shard> shards;
  final double t; // 0..1 progress
  final double shardPixel;

  _BurstPainter({
    required this.image,
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
      final side = _frameSize * shardPixel * s.sizeJitter;

      // Advance through the sheet for the spin; wrap into [0, _frameCount).
      final frame =
          ((s.startFrame + s.spinFrames * t).floor() % _frameCount +
              _frameCount) %
          _frameCount;
      final src = Rect.fromLTWH(
        (frame * _frameSize).toDouble(),
        0,
        _frameSize.toDouble(),
        _frameSize.toDouble(),
      );
      final dst = Rect.fromCenter(center: pos, width: side, height: side);

      canvas.drawImageRect(
        image,
        src,
        dst,
        Paint()
          ..filterQuality = FilterQuality.none
          ..isAntiAlias = false
          // White sprite * colour = colour; alpha carries the fade.
          ..colorFilter = ColorFilter.mode(
            s.color.withValues(alpha: fade),
            BlendMode.modulate,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t || old.image != image;
}
