import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SpriteCarousel<T> extends StatefulWidget {
  final List<T> items;
  final int selectedIndex;
  final ValueChanged<int> onSelectedChanged;

  // Layout
  final double centerSize;
  final double sideSize;
  final double edgeSize;
  final double cellGap;
  final int peekCount;

  // Behavior
  final bool infiniteLoop;
  final bool centerBob;
  final double bobAmplitude;
  final Duration bobPeriod;
  final bool sideSquish;
  final bool sideFade;
  final bool centerBevel;

  final Widget Function(BuildContext, T item, double centerness, double targetSize) itemBuilder;

  const SpriteCarousel({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelectedChanged,
    required this.centerSize,
    required this.sideSize,
    required this.edgeSize,
    required this.cellGap,
    required this.peekCount,
    required this.infiniteLoop,
    required this.centerBob,
    required this.bobAmplitude,
    required this.bobPeriod,
    required this.sideSquish,
    required this.sideFade,
    required this.centerBevel,
    required this.itemBuilder,
  });

  @override
  State<SpriteCarousel<T>> createState() => _SpriteCarouselState<T>();
}

class _SpriteCarouselState<T> extends State<SpriteCarousel<T>>
    with SingleTickerProviderStateMixin {
  static const int _loopOffset = 1000;

  late PageController _controller;
  int _currentPage = 0;
  late AnimationController _bobController;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.infiniteLoop
        ? widget.items.length * _loopOffset + widget.selectedIndex
        : widget.selectedIndex;
    _controller = PageController(
      viewportFraction: 1.0 / widget.peekCount,
      initialPage: _currentPage,
    );
    _controller.addListener(_onScroll);

    _bobController = AnimationController(
      vsync: this,
      duration: widget.bobPeriod,
    );
    if (widget.centerBob && widget.bobAmplitude > 0) {
      _bobController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SpriteCarousel<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the items list itself changed (length or contents), reset the
    // controller to the new selectedIndex. Compare lengths (cheap) and fall
    // back to identity check for in-place mutations.
    final itemsChanged = oldWidget.items.length != widget.items.length ||
        !identical(oldWidget.items, widget.items);

    if (oldWidget.selectedIndex != widget.selectedIndex || itemsChanged) {
      if (_controller.hasClients &&
          !_controller.position.isScrollingNotifier.value) {
        final target = widget.infiniteLoop
            ? widget.items.length * _loopOffset + widget.selectedIndex
            : widget.selectedIndex;
        _currentPage = target;
        _controller.jumpToPage(target);
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    _bobController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final page = _controller.page;
    if (page == null) return;

    // Only fire when settled at an integer page position
    if ((page - page.round()).abs() > 0.01) return;

    final roundedPage = page.round();
    if (roundedPage == _currentPage) return;
    _currentPage = roundedPage;

    final rawIndex = roundedPage % widget.items.length;
    final positiveIndex = (rawIndex + widget.items.length) % widget.items.length;
    if (positiveIndex != widget.selectedIndex) {
      HapticFeedback.selectionClick();
      widget.onSelectedChanged(positiveIndex);
    }
  }

  void _animateToPage(int pageIndex) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _controller.jumpToPage(pageIndex);
      return;
    }
    _controller.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  int _itemIndexForPage(int pageIndex) {
    if (!widget.infiniteLoop) return pageIndex;
    return pageIndex % widget.items.length;
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce && _bobController.isAnimating) {
      _bobController.stop();
      _bobController.value = 0;
    } else if (!reduce && widget.centerBob && widget.bobAmplitude > 0 && !_bobController.isAnimating) {
      _bobController.repeat();
    }

    return SizedBox(
      height: widget.centerSize + widget.bobAmplitude * 2 + 16,
      child: PageView.builder(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        itemCount: widget.infiniteLoop ? null : widget.items.length,
        itemBuilder: (context, pageIndex) {
          final itemIndex = _itemIndexForPage(pageIndex);
          final item = widget.items[itemIndex];
          return _CarouselCell(
            pageIndex: pageIndex,
            initialPage: _currentPage,
            controller: _controller,
            bobController: _bobController,
            bobAmplitude: widget.centerBob ? widget.bobAmplitude : 0,
            onTap: () => _animateToPage(pageIndex),
            centerSize: widget.centerSize,
            sideSize: widget.sideSize,
            edgeSize: widget.edgeSize,
            sideSquish: widget.sideSquish,
            sideFade: widget.sideFade,
            builder: (centerness, targetSize) =>
                widget.itemBuilder(context, item, centerness, targetSize),
          );
        },
      ),
    );
  }
}

class _CarouselCell extends StatelessWidget {
  final int pageIndex;
  final int initialPage;
  final PageController controller;
  final AnimationController bobController;
  final double bobAmplitude;
  final VoidCallback onTap;
  final double centerSize;
  final double sideSize;
  final double edgeSize;
  final bool sideSquish;
  final bool sideFade;
  final Widget Function(double centerness, double targetSize) builder;

  const _CarouselCell({
    required this.pageIndex,
    required this.initialPage,
    required this.controller,
    required this.bobController,
    required this.bobAmplitude,
    required this.onTap,
    required this.centerSize,
    required this.sideSize,
    required this.edgeSize,
    required this.sideSquish,
    required this.sideFade,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, bobController]),
      builder: (context, _) {
        final page = controller.hasClients && controller.position.haveDimensions
            ? (controller.page ?? initialPage.toDouble())
            : initialPage.toDouble();
        final dRaw = (page - pageIndex).abs();
        final d = dRaw.clamp(0.0, 2.0);
        final centerness = (1.0 - d).clamp(0.0, 1.0);

        // Scale: lerp center→side over [0,1], side→edge over [1,2].
        final double targetSize;
        if (d <= 1.0) {
          targetSize = centerSize + (sideSize - centerSize) * d;
        } else {
          targetSize = sideSize + (edgeSize - sideSize) * (d - 1.0);
        }
        // Opacity.
        double opacity = 1.0;
        if (sideFade) {
          if (d <= 1.0) {
            opacity = 1.0 - 0.3 * d; // 1.0 → 0.7
          } else {
            opacity = 0.7 - 0.3 * (d - 1.0); // 0.7 → 0.4
          }
        }

        // Horizontal squish.
        double xScale = 1.0;
        if (sideSquish) {
          xScale = 1.0 - 0.15 * d.clamp(0.0, 1.0) - 0.15 * (d - 1.0).clamp(0.0, 1.0);
        }

        // Bob: only the center-most cell actually moves; weight by centerness.
        final bobDy = bobAmplitude > 0
            ? (-bobAmplitude *
                    math.sin(bobController.value * 2 * math.pi) *
                    centerness)
                .roundToDouble()
            : 0.0;

        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: Transform.translate(
              offset: Offset(0, bobDy),
              child: Opacity(
                opacity: opacity,
                child: SizedBox(
                  width: targetSize * xScale,
                  height: targetSize,
                  child: OverflowBox(
                    minWidth: 0,
                    maxWidth: double.infinity,
                    minHeight: 0,
                    maxHeight: double.infinity,
                    alignment: Alignment.center,
                    child: builder(centerness, targetSize),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
