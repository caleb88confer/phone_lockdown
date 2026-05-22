import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A one-shot pixel-art burst: small rotating-shard sprites fire out from the
/// centre, each spinning at its own steady rate, until it vanishes. Plays once
/// when first built, so mount it at the moment you want the explosion (e.g. when
/// a lock lands).
///
/// A shard begins to vanish at whichever comes first: it reaches the vanish ring
/// ([radius]), or [duration] elapses. Either way it then dissolves over a short
/// tail, so the whole burst runs for [duration] plus that tail (see
/// [totalDuration]). Spin speed is independent of [duration] — a shorter burst
/// no longer means a faster spin.
///
/// The shard art lives in a horizontal sprite sheet of [_frameCount] square
/// frames showing one shard turning. The sheet is pure white, so each shard is
/// tinted to its swatch with a [BlendMode.modulate] colour filter (white *
/// colour = colour), which also carries the fade.
class PixelBurst extends StatefulWidget {
  /// Shard colours, chosen at random per shard. Pass the lock's swatch + white.
  final List<Color> colors;

  /// Optional per-colour weights aligned 1:1 with [colors]. When given (and
  /// usable), each shard's colour is drawn in proportion to these instead of
  /// uniformly — used to bias the lock-palette burst toward lighter colours.
  final List<double>? weights;

  final int count;

  /// Base distance (logical px) a shard travels; jittered per shard.
  final double travel;

  /// Logical px per sprite pixel — each shard is [kShardFrameSize] of these square.
  final double shardPixel;

  /// Spin speed in full sprite loops per second. Steady for a shard's whole
  /// life and unrelated to [duration]; the direction is randomised per shard.
  final double spinRate;

  /// Per-shard deviation around [spinRate]: 0 = every shard spins at the same
  /// speed, 1 = speeds fan out ±100% (some still, some twice as fast).
  final double spinRandomizer;

  /// Per-shard deviation around [travel]: 0 = every shard flies the same
  /// distance, 1 = distances fan out ±100% (some barely move, some go twice).
  final double speedRandomizer;

  /// Per-shard deviation around the shard size: 0 = every shard is identical
  /// (and matches the lock's pixel grid at size 1×), 1 = sizes fan out ±100%.
  final double sizeRandomizer;

  /// Vanish ring, in logical px from the centre. A shard whose reach crosses
  /// this radius stops there and begins dissolving the instant it arrives.
  /// Shards that never reach the ring instead live until [duration]. Pass
  /// [double.infinity] (the default) to disable the ring.
  final double radius;

  /// How long a shard that never reaches the ring lives before it begins to
  /// vanish. After the trigger (ring or this), the shard dissolves over an extra
  /// tail; [totalDuration] is the full run including that tail.
  final Duration duration;

  /// Per-shard deviation around [duration] for ring-free shards: 0 = every
  /// shard vanishes at the same time, 1 = vanish times fan out ±100% (some go
  /// early, some live up to twice as long). Only affects time-based vanishing;
  /// shards that hit the ring still vanish on arrival.
  final double lifetimeRandomizer;

  final int seed;

  const PixelBurst({
    super.key,
    required this.colors,
    this.weights,
    this.count = 30,
    this.travel = 160,
    this.shardPixel = 4,
    this.spinRate = 3,
    this.spinRandomizer = 0,
    this.speedRandomizer = 0,
    this.sizeRandomizer = 0,
    this.radius = double.infinity,
    this.duration = const Duration(milliseconds: 600),
    this.lifetimeRandomizer = 0,
    this.seed = 0,
  });

  /// The full burst length: the longest a shard can live (its [life] stretched
  /// by [lifetimeRandomizer]) plus the dissolve tail. Hosts use this to keep the
  /// burst on screen until the last, longest-lived shard has finished fading.
  static Duration totalDuration(Duration life, [double lifetimeRandomizer = 0]) =>
      life * (1 + lifetimeRandomizer + _fadeFraction);

  @override
  State<PixelBurst> createState() => _PixelBurstState();
}

// Sprite sheet: a single shard turning, laid out as [_frameCount] square
// [kShardFrameSize]x[kShardFrameSize] frames in a horizontal strip.
const String _shardAsset = 'assets/sprites/rotating_shard.png';

/// Side of one shard sprite frame, in sprite pixels. A shard renders this many
/// [PixelBurst.shardPixel]-sized squares across, so a desired on-screen shard
/// side maps to `shardPixel = side / kShardFrameSize`.
const int kShardFrameSize = 5;
const int _frameCount = 8;

// The dissolve tail, as a fraction of a shard's life. A shard holds full
// opacity until its vanish trigger, then fades out over (life * _fadeFraction).
const double _fadeFraction = 0.35;

/// A per-shard multiplier centred on 1.0: with [randomizer] 0 it is always 1.0
/// (uniform), and as it grows the result fans out symmetrically over
/// [1 - randomizer, 1 + randomizer], floored at 0 so nothing reverses.
double _deviate(math.Random rng, double randomizer) {
  if (randomizer <= 0) return 1.0;
  final dev = 1 + (rng.nextDouble() * 2 - 1) * randomizer;
  return dev < 0 ? 0.0 : dev;
}

/// Running totals of [weights] for weighted index selection, or null when the
/// weights are absent, the wrong length, or sum to nothing — selection then
/// falls back to uniform.
List<double>? _cumulativeWeights(List<double>? weights, int n) {
  if (weights == null || weights.length != n) return null;
  final cum = List<double>.filled(n, 0);
  var sum = 0.0;
  for (var i = 0; i < n; i++) {
    if (weights[i] > 0) sum += weights[i];
    cum[i] = sum;
  }
  return sum > 0 ? cum : null;
}

/// An index in [0, n): weighted by [cum] when present, otherwise uniform.
int _weightedIndex(math.Random rng, List<double>? cum, int n) {
  if (cum == null) return rng.nextInt(n);
  final r = rng.nextDouble() * cum[n - 1];
  for (var i = 0; i < n; i++) {
    if (r < cum[i]) return i;
  }
  return n - 1;
}

class _PixelBurstState extends State<PixelBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Shard> _shards;
  late final double _lifeMs; // travel + spin window before leftovers vanish
  late final double _fadeMs; // dissolve tail length
  late final double _maxLifeMs; // longest a shard can live (life + jitter)

  ui.Image? _image;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _lifeMs = widget.duration.inMicroseconds / 1000;
    _fadeMs = _lifeMs * _fadeFraction;
    // The latest a ring-free shard can begin to vanish: its life can stretch by
    // up to +lifetimeRandomizer (see _deviate). Drives the controller length.
    _maxLifeMs = _lifeMs * (1 + widget.lifetimeRandomizer);

    final rng = math.Random(widget.seed);
    final slice = 2 * math.pi / widget.count;
    final colorCum = _cumulativeWeights(widget.weights, widget.colors.length);
    _shards = List.generate(widget.count, (i) {
      // Spread directions evenly around the circle, then jitter within a slice
      // so the burst reads as radial but not mechanically regular.
      final angle = i * slice + (rng.nextDouble() - 0.5) * slice;
      final distance = widget.travel * _deviate(rng, widget.speedRandomizer);

      // When does this shard begin to vanish? If its reach crosses the ring, the
      // instant it arrives there; otherwise when its life runs out. Travel eases
      // out over the life (easeOutCubic), so the ring-crossing fraction inverts
      // to 1 - cbrt(1 - r). A ring-free shard lives for the burst's life,
      // jittered per shard so they don't all wink out together.
      final hitsRing = widget.radius < distance;
      final clampDistance = hitsRing ? widget.radius : double.infinity;
      final vanishStartMs = hitsRing
          ? (1 - math.pow(1 - widget.radius / distance, 1 / 3).toDouble()) *
                _lifeMs
          : _lifeMs * _deviate(rng, widget.lifetimeRandomizer);

      // Spin speed: signed sprite frames per ms, steady for the shard's life.
      final loopsPerSec = widget.spinRate * _deviate(rng, widget.spinRandomizer);
      final dir = rng.nextBool() ? 1.0 : -1.0;

      return _Shard(
        angle: angle,
        distance: distance,
        clampDistance: clampDistance,
        vanishStartMs: vanishStartMs,
        framesPerMs: dir * loopsPerSec * _frameCount / 1000,
        startFrame: rng.nextInt(_frameCount),
        color: widget.colors[_weightedIndex(rng, colorCum, widget.colors.length)],
        sizeJitter: _deviate(rng, widget.sizeRandomizer),
      );
    });

    _resolveImage();
    _controller = AnimationController(
      vsync: this,
      duration: PixelBurst.totalDuration(
        widget.duration,
        widget.lifetimeRandomizer,
      ),
    )..forward();
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
            elapsedMs: _controller.value * (_maxLifeMs + _fadeMs),
            lifeMs: _lifeMs,
            fadeMs: _fadeMs,
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
  final double clampDistance; // travel is capped here (the ring), or infinity
  final double vanishStartMs; // ms into the burst when this shard starts fading
  final double framesPerMs; // sprite frames advanced per ms (signed)
  final int startFrame; // initial sprite frame
  final Color color;
  final double sizeJitter;

  const _Shard({
    required this.angle,
    required this.distance,
    required this.clampDistance,
    required this.vanishStartMs,
    required this.framesPerMs,
    required this.startFrame,
    required this.color,
    required this.sizeJitter,
  });
}

class _BurstPainter extends CustomPainter {
  final ui.Image image;
  final List<_Shard> shards;
  final double elapsedMs; // ms since the burst started
  final double lifeMs; // travel window before leftovers vanish
  final double fadeMs; // dissolve tail length
  final double shardPixel;

  _BurstPainter({
    required this.image,
    required this.shards,
    required this.elapsedMs,
    required this.lifeMs,
    required this.fadeMs,
    required this.shardPixel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Travel eases out over the life, then holds while the shard dissolves.
    final moveT = (elapsedMs / lifeMs).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(moveT);

    for (final s in shards) {
      // Hold full opacity until this shard's vanish trigger, then fade over the
      // tail — the trigger is the ring crossing for shards that reach it, the
      // end of life for the rest.
      final fade = elapsedMs < s.vanishStartMs
          ? 1.0
          : (1 - (elapsedMs - s.vanishStartMs) / fadeMs).clamp(0.0, 1.0);
      if (fade <= 0) continue;

      final d = math.min(s.distance * eased, s.clampDistance);
      final pos = center + Offset(math.cos(s.angle), math.sin(s.angle)) * d;
      final side = kShardFrameSize * shardPixel * s.sizeJitter;

      // Spin at a steady real-time rate; wrap the frame into [0, _frameCount).
      final frame =
          ((s.startFrame + s.framesPerMs * elapsedMs).floor() % _frameCount +
              _frameCount) %
          _frameCount;
      final src = Rect.fromLTWH(
        (frame * kShardFrameSize).toDouble(),
        0,
        kShardFrameSize.toDouble(),
        kShardFrameSize.toDouble(),
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
  bool shouldRepaint(_BurstPainter old) =>
      old.elapsedMs != elapsedMs || old.image != image;
}
