import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class SpriteFrame extends StatefulWidget {
  final String assetPath;
  final int frameWidth;
  final int frameHeight;
  final int frameIndex;
  final double size;

  const SpriteFrame({
    super.key,
    required this.assetPath,
    required this.frameWidth,
    required this.frameHeight,
    required this.frameIndex,
    required this.size,
  });

  @override
  State<SpriteFrame> createState() => _SpriteFrameState();
}

class _SpriteFrameState extends State<SpriteFrame> {
  ui.Image? _image;
  ImageStream? _stream;
  late ImageStreamListener _listener;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(SpriteFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _stream?.removeListener(_listener);
      _image = null;
      _resolve();
    }
  }

  void _resolve() {
    final provider = AssetImage(widget.assetPath);
    final newStream = provider.resolve(ImageConfiguration.empty);
    _listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      setState(() => _image = info.image);
    });
    newStream.addListener(_listener);
    _stream = newStream;
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) {
      return SizedBox(width: widget.size, height: widget.size);
    }
    final aspect = widget.frameWidth / widget.frameHeight;
    final w = aspect >= 1 ? widget.size : widget.size * aspect;
    final h = aspect >= 1 ? widget.size / aspect : widget.size;
    return SizedBox(
      width: w,
      height: h,
      child: CustomPaint(
        painter: _SpritePainter(
          image: image,
          frameIndex: widget.frameIndex,
          frameWidth: widget.frameWidth,
          frameHeight: widget.frameHeight,
        ),
      ),
    );
  }
}

class _SpritePainter extends CustomPainter {
  final ui.Image image;
  final int frameIndex;
  final int frameWidth;
  final int frameHeight;

  _SpritePainter({
    required this.image,
    required this.frameIndex,
    required this.frameWidth,
    required this.frameHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
      (frameIndex * frameWidth).toDouble(),
      0,
      frameWidth.toDouble(),
      frameHeight.toDouble(),
    );
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..filterQuality = FilterQuality.none;
    canvas.drawImageRect(image, src, dst, paint);
  }

  @override
  bool shouldRepaint(_SpritePainter old) =>
      old.image != image ||
      old.frameIndex != frameIndex ||
      old.frameWidth != frameWidth ||
      old.frameHeight != frameHeight;
}

class AnimatedSprite extends StatefulWidget {
  final String assetPath;
  final int frameWidth;
  final int frameHeight;
  final int frameCount;
  final int startFrame;
  final int endFrame;
  final Duration duration;
  final bool loop;
  final VoidCallback? onComplete;
  final double size;

  const AnimatedSprite({
    super.key,
    required this.assetPath,
    required this.frameWidth,
    required this.frameHeight,
    required this.frameCount,
    required this.startFrame,
    required this.endFrame,
    required this.duration,
    required this.size,
    this.loop = false,
    this.onComplete,
  });

  @override
  State<AnimatedSprite> createState() => _AnimatedSpriteState();
}

class _AnimatedSpriteState extends State<AnimatedSprite>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _frame;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _frame = IntTween(begin: widget.startFrame, end: widget.endFrame)
        .animate(_controller);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (widget.loop) {
          _controller.forward(from: 0);
        } else {
          widget.onComplete?.call();
        }
      }
    });
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startFrame != widget.startFrame ||
        oldWidget.endFrame != widget.endFrame ||
        oldWidget.assetPath != widget.assetPath ||
        oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
      _frame = IntTween(begin: widget.startFrame, end: widget.endFrame)
          .animate(_controller);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _frame,
      builder: (_, __) => SpriteFrame(
        assetPath: widget.assetPath,
        frameWidth: widget.frameWidth,
        frameHeight: widget.frameHeight,
        frameIndex: _frame.value.clamp(0, widget.frameCount - 1),
        size: widget.size,
      ),
    );
  }
}
