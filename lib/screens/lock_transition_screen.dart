import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../customization/lock_catalog.dart';
import '../services/explosion_settings.dart';
import '../theme/app_colors.dart';
import '../theme/bevel.dart';
import '../widgets/pixel_burst.dart';
import '../widgets/sprite_palette.dart';
import '../widgets/sprite_sheet.dart';
import 'explosion_settings_screen.dart';

/// Full-screen flourish shown right after a successful key scan. It re-creates
/// the home screen's lock (static — no idle bob), plays the lock/unlock sprite
/// transition, then lands the moment with a white flash, a haptic tap, a small
/// tilt, a pixel-shard burst, and a background-colour swap.
///
/// The real blocking state change runs via [onApply] while this screen covers
/// the home, so the home updates out of sight and is settled by the time we
/// pop. [onApply] returns null on success or an error message; that error is
/// handed back to the caller via [Navigator.pop].
///
/// When [ExplosionSettings.setupMode] is on, the screen does not auto-pop after
/// the burst — it shows close / replay / adjust controls so the burst can be
/// tuned and replayed without re-scanning (replays never re-run [onApply]).
class LockTransitionScreen extends StatefulWidget {
  final LockStyle style;
  final LockColorOption color;

  /// Direction of travel. true = locking (open -> closed), false = unlocking.
  final bool toBlocking;

  final Color startColor;
  final Color endColor;

  final Future<String?> Function() onApply;

  const LockTransitionScreen({
    super.key,
    required this.style,
    required this.color,
    required this.toBlocking,
    required this.startColor,
    required this.endColor,
    required this.onApply,
  });

  @override
  State<LockTransitionScreen> createState() => _LockTransitionScreenState();
}

class _LockTransitionScreenState extends State<LockTransitionScreen>
    with TickerProviderStateMixin {
  // Beat showing the start pose before the lock moves, so the change registers.
  static const _startHold = Duration(milliseconds: 280);
  // Extra beat on the landed pose after the burst finishes, before returning to
  // the home screen. The full hold is the burst length plus this (see _run).
  static const _endMargin = Duration(milliseconds: 120);

  late final AnimationController _flashController;
  late final Animation<double> _flash;
  late final AnimationController _tiltController;
  late final Animation<double> _tilt;

  bool _playing = false;
  bool _climaxed = false; // climax fired: flash overlay + burst are now live
  bool _landed = false; // end colour shown, lock tilted
  bool _showControls = false; // setup mode: controls visible after a play
  int _replayCount = 0; // bumps each play so the burst widget remounts fresh

  // The equipped lock's own colours, decoded once for the lock-palette burst.
  // Null until loaded (or if decoding fails); the burst falls back to the
  // custom palette in that case. Loaded eagerly so it is ready by the climax
  // even when the user flips the mode on and replays from the setup controls.
  List<Color>? _lockPalette;

  @override
  void initState() {
    super.initState();
    _loadLockPalette();

    // At the climax the overlay snaps to near-opaque (hiding the background
    // colour swap underneath it) then fades out, revealing the new colour.
    // It is not rendered at all before the climax — see [_climaxed] in build.
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _flash = Tween<double>(begin: 0.95, end: 0.0).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeOut),
    );

    _tiltController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    final tiltAngle = widget.toBlocking ? 0.10 : -0.10;
    _tilt = Tween<double>(begin: 0.0, end: tiltAngle).animate(
      CurvedAnimation(parent: _tiltController, curve: Curves.elasticOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _loadLockPalette() async {
    final path = widget.style.spritesheetPath(widget.color.id);
    final palette = await SpritePalette.of(path);
    if (!mounted || palette.isEmpty) return;
    setState(() => _lockPalette = palette);
  }

  Future<void> _run() async {
    // Apply the real lock/unlock once while we cover the home. On failure, bail
    // out immediately and hand the error back to the caller to surface.
    final error = await widget.onApply();
    if (!mounted) return;
    if (error != null) {
      Navigator.of(context).pop(error);
      return;
    }
    await _playVisuals();
  }

  /// Resets to the start pose and plays the sprite transition. Used for the
  /// first play and for the setup-mode replay button — it never touches
  /// [onApply], so replays don't toggle the real lock again.
  Future<void> _playVisuals() async {
    _flashController.value = 0;
    _tiltController.value = 0;
    setState(() {
      _replayCount++;
      _playing = false;
      _climaxed = false;
      _landed = false;
      _showControls = false;
    });
    await Future.delayed(_startHold);
    if (!mounted) return;
    setState(() => _playing = true);
  }

  Future<void> _onAnimationComplete() async {
    if (!mounted || _climaxed) return;
    HapticFeedback.mediumImpact();
    // Swap the colour and arm the flash in the same frame so the overlay (which
    // starts near-opaque) hides the swap, then forward() fades it away.
    setState(() {
      _climaxed = true;
      _landed = true;
    });
    _flashController.forward(from: 0);
    _tiltController.forward(from: 0);

    // Hold until the burst (including its dissolve tail) is done, plus a beat.
    final settings = context.read<ExplosionSettings>();
    await Future.delayed(
      PixelBurst.totalDuration(settings.duration) + _endMargin,
    );
    if (!mounted) return;
    if (settings.setupMode) {
      setState(() => _showControls = true);
    } else {
      Navigator.of(context).pop(null);
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ExplosionSettingsScreen()),
    );
    if (!mounted) return;
    _playVisuals(); // replay so the new values are visible immediately
  }

  @override
  void dispose() {
    _flashController.dispose();
    _tiltController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<ExplosionSettings>();
    final bg = _landed ? widget.endColor : widget.startColor;
    final screen = MediaQuery.of(context).size;
    final size = screen.height / 4;
    // On-screen size of one lock sprite pixel. The burst matches it at shard
    // size 1× so the shard art shares the lock's pixel grid (no mixed pixel
    // sizes — "mixels"); scaling shard size away from 1× is then a choice.
    final lockPixel =
        size * widget.style.displayScale / widget.style.frameWidth;

    // Shard colours: the lock's own palette when that mode is on and a palette
    // has loaded, otherwise the custom swatches. With more lock colours than
    // shards we hand the burst a random subset sized to the shard count.
    final lockPalette = _lockPalette;
    final usingLockPalette =
        settings.useLockPalette &&
        lockPalette != null &&
        lockPalette.isNotEmpty;
    final burstColors = usingLockPalette
        ? pickBurstColors(lockPalette, settings.count)
        : settings.colors;
    // Skew the lock palette toward its lighter colours; the custom palette is
    // always picked evenly.
    final burstWeights = usingLockPalette
        ? lightnessWeights(burstColors, settings.lightnessBias)
        : null;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Burst sits at the back so shards never cover the lock; the lock is
          // drawn over it, and the flash sits on top of both. The stable keys
          // matter: the burst is inserted at the front at the climax, so without
          // keys Flutter would match children by position and rebuild the lock's
          // sprite (restarting its animation) when the burst appears.
          if (_climaxed)
            Positioned.fill(
              key: const ValueKey('burst'),
              child: PixelBurst(
                key: ValueKey(_replayCount),
                colors: burstColors,
                weights: burstWeights,
                count: settings.count,
                travel: size * 1.15 * settings.explosionSpeed,
                radius: settings.ringEnabled
                    ? size * 1.15 * settings.radius
                    : double.infinity,
                shardPixel: lockPixel * settings.sizeScale,
                sizeRandomizer: settings.sizeRandomizer,
                spinRate: settings.spinRate,
                spinRandomizer: settings.spinRandomizer,
                speedRandomizer: settings.speedRandomizer,
                duration: settings.duration,
              ),
            ),
          Positioned.fill(
            key: const ValueKey('lock'),
            child: Center(
              child: AnimatedBuilder(
                animation: _tilt,
                builder: (_, child) =>
                    Transform.rotate(angle: _tilt.value, child: child),
                child: _buildSprite(size),
              ),
            ),
          ),
          Positioned.fill(
            key: const ValueKey('flash'),
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _flash,
                builder: (_, _) => ColoredBox(
                  color: Colors.white.withValues(
                    alpha: _climaxed ? _flash.value : 0.0,
                  ),
                ),
              ),
            ),
          ),
          if (settings.setupMode) _buildReadout(settings),
          if (settings.setupMode && _showControls) _buildControls(),
        ],
      ),
    );
  }

  Widget _buildReadout(ExplosionSettings s) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'count ${s.count}   ·   size ${s.sizeScale.toStringAsFixed(2)}× ±${s.sizeRandomizer.toStringAsFixed(2)}   ·   '
              'speed ${s.explosionSpeed.toStringAsFixed(2)}× ±${s.speedRandomizer.toStringAsFixed(2)}   ·   '
              'radius ${s.ringEnabled ? '${s.radius.toStringAsFixed(2)}×' : 'off'}   ·   '
              'spin ${s.spinRate.toStringAsFixed(1)}/s ±${s.spinRandomizer.toStringAsFixed(2)}   ·   '
              '${s.durationMs}ms',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: MediaQuery.of(context).padding.bottom + 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _circleButton(
            Icons.close,
            'Close',
            () => Navigator.of(context).pop(null),
          ),
          const SizedBox(width: 24),
          _circleButton(Icons.replay, 'Replay', () => _playVisuals()),
          const SizedBox(width: 24),
          _circleButton(Icons.tune, 'Adjust', () => _openSettings()),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, String tip, VoidCallback onTap) {
    return Container(
      decoration: Bevel.raised(fill: AppColors.surfaceContainerHigh),
      child: IconButton(
        icon: Icon(icon, size: 24),
        tooltip: tip,
        color: AppColors.onSurface,
        onPressed: onTap,
      ),
    );
  }

  Widget _buildSprite(double size) {
    final s = widget.style;
    final assetPath = s.spritesheetPath(widget.color.id);
    final renderSize = size * s.displayScale;

    final Widget sprite;
    if (_playing) {
      // Locking plays open->closed (closingRange); unlocking plays closed->open
      // (openingRange). After completion the sprite holds its final frame.
      final (start, end) = widget.toBlocking ? s.closingRange : s.openingRange;
      final framesPlayed = (end - start).abs() + 1;
      sprite = AnimatedSprite(
        assetPath: assetPath,
        frameWidth: s.frameWidth,
        frameHeight: s.frameHeight,
        frameCount: s.frameCount,
        startFrame: start,
        endFrame: end,
        duration: s.durationFor(framesPlayed),
        size: renderSize,
        onComplete: _onAnimationComplete,
      );
    } else {
      // Resting pose of the start state: open when locking, closed when
      // unlocking — mirrors LockDisplay's resting-frame choice.
      final restingFrame = widget.toBlocking ? s.openFrame : s.lockedFrame;
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
