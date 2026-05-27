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
  // Pixels to push the immediate side cells (|d|≈1) outward, away from the
  // center cell. Tapers to 0 at the center and at the edge cells (|d|=2).
  final double sideOutwardOffset;

  // Behavior
  final bool infiniteLoop;
  final bool centerBob;
  final double bobAmplitude;
  final Duration bobPeriod;
  final bool sideSquish;
  final bool sideFade;
  final bool centerBevel;

  final Widget Function(
    BuildContext,
    T item,
    double centerness,
    double targetSize,
  )
  itemBuilder;

  /// Optional predicate: when true for an item, the carousel treats it as a
  /// hard wall — the user can see it in the side/edge slots but the scroll
  /// physics refuses to let the center cell cross into it. The navigable
  /// range is the contiguous run of non-locked items around [selectedIndex].
  /// Taps on locked cells are also a no-op.
  final bool Function(T item)? isItemLocked;

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
    this.sideOutwardOffset = 0,
    required this.infiniteLoop,
    required this.centerBob,
    required this.bobAmplitude,
    required this.bobPeriod,
    required this.sideSquish,
    required this.sideFade,
    required this.centerBevel,
    required this.itemBuilder,
    this.isItemLocked,
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
    final itemsChanged =
        oldWidget.items.length != widget.items.length ||
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
    final positiveIndex =
        (rawIndex + widget.items.length) % widget.items.length;
    if (positiveIndex != widget.selectedIndex) {
      HapticFeedback.selectionClick();
      widget.onSelectedChanged(positiveIndex);
    }
  }

  /// Contiguous range of non-locked items around the current selection. The
  /// custom physics uses this as a hard scroll wall. With [infiniteLoop] on,
  /// or no [isItemLocked] callback, returns the full range so physics is a
  /// no-op.
  (int, int) _navigableRange() {
    final lockedCheck = widget.isItemLocked;
    if (lockedCheck == null || widget.infiniteLoop) {
      return (0, widget.items.length - 1);
    }
    var minIndex = widget.selectedIndex.clamp(0, widget.items.length - 1);
    while (minIndex > 0 && !lockedCheck(widget.items[minIndex - 1])) {
      minIndex--;
    }
    var maxIndex = widget.selectedIndex.clamp(0, widget.items.length - 1);
    while (maxIndex < widget.items.length - 1 &&
        !lockedCheck(widget.items[maxIndex + 1])) {
      maxIndex++;
    }
    return (minIndex, maxIndex);
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
    } else if (!reduce &&
        widget.centerBob &&
        widget.bobAmplitude > 0 &&
        !_bobController.isAnimating) {
      _bobController.repeat();
    }

    final (minPage, maxPage) = _navigableRange();
    final useBoundedPhysics =
        !widget.infiniteLoop && widget.isItemLocked != null;

    return SizedBox(
      height: widget.centerSize + widget.bobAmplitude * 2 + 16,
      child: PageView.builder(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        itemCount: widget.infiniteLoop ? null : widget.items.length,
        physics: useBoundedPhysics
            ? _BoundedPagePhysics(
                minPage: minPage,
                maxPage: maxPage,
                viewportFraction: 1.0 / widget.peekCount,
              )
            : null,
        itemBuilder: (context, pageIndex) {
          final itemIndex = _itemIndexForPage(pageIndex);
          final item = widget.items[itemIndex];
          final lockedCheck = widget.isItemLocked;
          final tapLocked =
              lockedCheck != null && lockedCheck(item);
          return _CarouselCell(
            pageIndex: pageIndex,
            initialPage: _currentPage,
            controller: _controller,
            bobController: _bobController,
            bobAmplitude: widget.centerBob ? widget.bobAmplitude : 0,
            onTap: tapLocked ? null : () => _animateToPage(pageIndex),
            centerSize: widget.centerSize,
            sideSize: widget.sideSize,
            edgeSize: widget.edgeSize,
            sideOutwardOffset: widget.sideOutwardOffset,
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
  final VoidCallback? onTap;
  final double centerSize;
  final double sideSize;
  final double edgeSize;
  final double sideOutwardOffset;
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
    required this.sideOutwardOffset,
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
        final signedD = (pageIndex - page).clamp(-2.0, 2.0);
        final dRaw = signedD.abs();
        final d = dRaw.clamp(0.0, 2.0);
        final centerness = (1.0 - d).clamp(0.0, 1.0);

        // Triangular weight peaking at |d|=1 (the side cells), zero at center
        // and at the edge cells.
        final sideWeight = (1.0 - (d - 1.0).abs()).clamp(0.0, 1.0);
        final outwardDx = signedD.sign * sideOutwardOffset * sideWeight;

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
          xScale =
              1.0 - 0.15 * d.clamp(0.0, 1.0) - 0.15 * (d - 1.0).clamp(0.0, 1.0);
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
              offset: Offset(outwardDx, bobDy),
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

/// PageScrollPhysics variant that walls off pages outside [minPage..maxPage].
/// The PageView still renders cells outside that range (so locked silhouettes
/// stay visible in the side/edge slots), but drags and flings cannot park the
/// centre cell on them — the boundary behaves like the natural start/end of a
/// non-looping PageView.
///
/// Implementation: [applyBoundaryConditions] returns overscroll for any drag
/// past the bounds, and [createBallisticSimulation] clamps the post-fling
/// target into the range so a flick can't overshoot into the locked zone.
class _BoundedPagePhysics extends PageScrollPhysics {
  final int minPage;
  final int maxPage;
  final double viewportFraction;

  const _BoundedPagePhysics({
    required this.minPage,
    required this.maxPage,
    required this.viewportFraction,
    super.parent,
  });

  @override
  _BoundedPagePhysics applyTo(ScrollPhysics? ancestor) {
    return _BoundedPagePhysics(
      minPage: minPage,
      maxPage: maxPage,
      viewportFraction: viewportFraction,
      parent: buildParent(ancestor),
    );
  }

  double _pageWidth(ScrollMetrics position) =>
      position.viewportDimension * viewportFraction;

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final pageW = _pageWidth(position);
    final minPx = minPage * pageW;
    final maxPx = maxPage * pageW;

    // Already past min and moving further past — refuse the whole delta.
    if (value < position.pixels && position.pixels <= minPx) {
      return value - position.pixels;
    }
    // Already past max and moving further past — refuse the whole delta.
    if (maxPx <= position.pixels && position.pixels < value) {
      return value - position.pixels;
    }
    // Crossing min from inside — clamp at min.
    if (value < minPx && minPx < position.pixels) {
      return value - minPx;
    }
    // Crossing max from inside — clamp at max.
    if (position.pixels < maxPx && maxPx < value) {
      return value - maxPx;
    }
    return 0.0;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final pageW = _pageWidth(position);
    final tolerance = toleranceFor(position);

    // Same target-page logic as PageScrollPhysics: nudge half a page in the
    // direction of the fling, then round to the nearest page. The clamp keeps
    // a fast flick from sailing past the wall.
    var page = position.pixels / pageW;
    if (velocity < -tolerance.velocity) {
      page -= 0.5;
    } else if (velocity > tolerance.velocity) {
      page += 0.5;
    }
    final targetPage =
        page.roundToDouble().clamp(minPage.toDouble(), maxPage.toDouble());
    final target = targetPage * pageW;

    if ((target - position.pixels).abs() < tolerance.distance) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }
}
