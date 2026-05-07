import 'package:flutter/material.dart';

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

  final Widget Function(BuildContext, T item, double centerness) itemBuilder;

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

class _SpriteCarouselState<T> extends State<SpriteCarousel<T>> {
  static const int _loopOffset = 1000;

  late PageController _controller;
  int _currentPage = 0;

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
  }

  @override
  void didUpdateWidget(covariant SpriteCarousel<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      final target = widget.infiniteLoop
          ? widget.items.length * _loopOffset + widget.selectedIndex
          : widget.selectedIndex;
      if (_controller.hasClients) {
        _controller.jumpToPage(target);
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
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
      widget.onSelectedChanged(positiveIndex);
    }
  }

  void _animateToPage(int pageIndex) {
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
            onTap: () => _animateToPage(pageIndex),
            child: widget.itemBuilder(context, item, 1.0),
          );
        },
      ),
    );
  }
}

class _CarouselCell extends StatelessWidget {
  final int pageIndex;
  final VoidCallback onTap;
  final Widget child;

  const _CarouselCell({
    required this.pageIndex,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Center(child: child),
    );
  }
}
