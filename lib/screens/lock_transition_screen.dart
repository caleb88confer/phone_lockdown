import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../customization/lock_catalog.dart';
import '../widgets/sprite_sheet.dart';

/// Full-screen flourish shown right after a successful key scan. It re-creates
/// the home screen's lock (static — no idle bob), plays the lock/unlock sprite
/// transition, then lands the moment with a white flash, a haptic tap, a small
/// tilt, and a background-colour swap — making the lock/unlock feel deliberate.
///
/// The real blocking state change runs via [onApply] while this screen covers
/// the home, so the home updates out of sight and is settled by the time we
/// pop. [onApply] returns null on success or an error message; that error is
/// handed back to the caller via [Navigator.pop].
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
  // Beat resting on the landed pose before returning to the home screen.
  static const _endHold = Duration(milliseconds: 650);

  late final AnimationController _flashController;
  late final Animation<double> _flash;
  late final AnimationController _tiltController;
  late final Animation<double> _tilt;

  bool _playing = false;
  bool _climaxed = false; // climax fired: flash overlay is now live
  bool _landed = false; // end colour shown, lock tilted

  @override
  void initState() {
    super.initState();

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

  Future<void> _run() async {
    // Apply the real lock/unlock while we cover the home. On failure, bail out
    // immediately and hand the error back to the caller to surface.
    final error = await widget.onApply();
    if (!mounted) return;
    if (error != null) {
      Navigator.of(context).pop(error);
      return;
    }

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

    await Future.delayed(_endHold);
    if (mounted) Navigator.of(context).pop(null);
  }

  @override
  void dispose() {
    _flashController.dispose();
    _tiltController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = _landed ? widget.endColor : widget.startColor;
    final size = MediaQuery.of(context).size.height / 4;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          Positioned.fill(
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
        ],
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
