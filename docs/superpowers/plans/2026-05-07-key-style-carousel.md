# Key Style & Color Carousel — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the flat key style/color pickers in the Edit Profile > Set Key section with a 5-cell horizontal carousel for style (center-large with vertical bob, infinite loop, all visible animations playing) and a 3-cell carousel for color (uniform size, bounce ends), with a "default to grey" rendering rule that lets the saved color persist across style scrolls.

**Architecture:** A reusable `SpriteCarousel<T>` widget built on Flutter's `PageView.builder` with `viewportFraction < 1` for the peek effect, `AnimatedBuilder` listening to the `PageController` for per-page scale/opacity/squish, and a separate `AnimationController` for the center bob. Two thin wrappers — `KeyStyleCarousel` and `KeyColorCarousel` — supply the keys-flavored and colors-flavored configs. The Set Key section absorbs both, the standalone "Key" picker is deleted, and the `keyColorForRender` resolver is threaded through every site that paints a saved key sprite (home screen, scan screen, code-row icon).

**Tech Stack:** Flutter (Dart), `flutter_test`, existing `AnimatedSprite`/`SpriteFrame`/`Bevel`/`AppColors` utilities. No new dependencies.

**Spec:** [docs/superpowers/specs/2026-05-07-key-style-carousel-design.md](../specs/2026-05-07-key-style-carousel-design.md)

---

## File map

**Create:**
- `lib/widgets/profile_form/carousel/sprite_carousel.dart` — generic `SpriteCarousel<T>` widget
- `lib/widgets/profile_form/carousel/key_style_carousel.dart` — keys-flavored wrapper
- `lib/widgets/profile_form/carousel/key_color_carousel.dart` — colors-flavored wrapper
- `lib/widgets/profile_form/set_key_section.dart` — replaces `unlock_code_section.dart`
- `test/widgets/profile_form/carousel/sprite_carousel_test.dart`
- `test/widgets/profile_form/carousel/key_style_carousel_test.dart`
- `test/widgets/profile_form/carousel/key_color_carousel_test.dart`
- `test/customization/key_catalog_test.dart`

**Modify:**
- `lib/customization/key_catalog.dart` — add `renderColorIdFor`, `colorCenterIndex`, `keyColorForRender`
- `lib/widgets/profile_form/profile_form_dialog.dart` — wire `SetKeySection`, drop `KeyStyleColorPicker`, simplify `_onKeyStyleChanged`
- `lib/screens/home_screen.dart` — replace `keyColorById` with `keyColorForRender` for key rendering

**Delete:**
- `lib/widgets/profile_form/unlock_code_section.dart` (renamed to `set_key_section.dart`)
- `lib/widgets/profile_form/key_picker.dart`

---

## Task 1: Add color-resolution helpers to `key_catalog.dart`

**Why first:** Pure functions, easy to TDD, and every subsequent UI piece depends on them.

**Files:**
- Modify: `lib/customization/key_catalog.dart`
- Create: `test/customization/key_catalog_test.dart`

- [ ] **Step 1.1: Write failing tests for the three helpers**

Create `test/customization/key_catalog_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_lockdown/customization/key_catalog.dart';

void main() {
  group('renderColorIdFor', () {
    test('returns saved color when style supports it', () {
      final style = keyStyleById('key_4');
      expect(renderColorIdFor(style, 'gold'), 'gold');
      expect(renderColorIdFor(style, 'bronze'), 'bronze');
    });

    test('falls back to grey when style does not support saved color', () {
      // key_4 has gold/silver/bronze/grey; curse is not supported.
      final style = keyStyleById('key_4');
      expect(renderColorIdFor(style, 'curse'), 'grey');
    });

    test('falls back to first color when style has neither saved nor grey', () {
      // Synthetic style for the defensive branch.
      const style = KeyStyle(
        id: 'synthetic', displayName: 'X', animated: false,
        frameCount: 1, frameWidth: 1, frameHeight: 1,
        colors: [KeyColorOption(id: 'rust', displayName: 'Rust', swatchColor: 0)],
      );
      expect(renderColorIdFor(style, 'gold'), 'rust');
    });
  });

  group('colorCenterIndex', () {
    test('returns the index of the saved color when supported', () {
      final style = keyStyleById('key_4');
      // _standardColors order: gold, silver, bronze, grey.
      expect(colorCenterIndex(style, 'gold'), 0);
      expect(colorCenterIndex(style, 'bronze'), 2);
    });

    test('returns the grey index when saved color is unsupported', () {
      final style = keyStyleById('key_4');
      // grey is at index 3 in _standardColors.
      expect(colorCenterIndex(style, 'curse'), 3);
    });

    test('returns 0 when neither saved color nor grey are present', () {
      const style = KeyStyle(
        id: 'synthetic', displayName: 'X', animated: false,
        frameCount: 1, frameWidth: 1, frameHeight: 1,
        colors: [KeyColorOption(id: 'rust', displayName: 'Rust', swatchColor: 0)],
      );
      expect(colorCenterIndex(style, 'gold'), 0);
    });
  });

  group('keyColorForRender', () {
    test('returns the resolved KeyColorOption (grey for unsupported)', () {
      final style = keyStyleById('key_4');
      final resolved = keyColorForRender(style, 'curse');
      expect(resolved.id, 'grey');
    });

    test('returns the saved KeyColorOption when supported', () {
      final style = keyStyleById('key_8');
      final resolved = keyColorForRender(style, 'curse');
      expect(resolved.id, 'curse');
    });
  });
}
```

- [ ] **Step 1.2: Run tests to verify they fail**

Run: `flutter test test/customization/key_catalog_test.dart`
Expected: FAIL — `renderColorIdFor`, `colorCenterIndex`, `keyColorForRender` are undefined.

- [ ] **Step 1.3: Add the three helpers to `key_catalog.dart`**

Append to `lib/customization/key_catalog.dart` (after `keyColorById`):

```dart
String renderColorIdFor(KeyStyle style, String savedColorId) {
  if (style.colors.any((c) => c.id == savedColorId)) return savedColorId;
  if (style.colors.any((c) => c.id == 'grey')) return 'grey';
  return style.colors.first.id;
}

int colorCenterIndex(KeyStyle style, String savedColorId) {
  final i = style.colors.indexWhere((c) => c.id == savedColorId);
  if (i != -1) return i;
  final greyI = style.colors.indexWhere((c) => c.id == 'grey');
  return greyI != -1 ? greyI : 0;
}

KeyColorOption keyColorForRender(KeyStyle style, String savedColorId) =>
    keyColorById(style, renderColorIdFor(style, savedColorId));
```

- [ ] **Step 1.4: Run tests to verify they pass**

Run: `flutter test test/customization/key_catalog_test.dart`
Expected: PASS — 8 tests passing.

- [ ] **Step 1.5: Commit**

```bash
git add lib/customization/key_catalog.dart test/customization/key_catalog_test.dart
git commit -m "feat: add grey-fallback resolvers for key (style, color) pairs"
```

---

## Task 2: Migrate render call sites to `keyColorForRender`

**Why now:** Decoupling the rendering policy from `keyColorById` lookups now means later tasks can rely on the new helper without changing semantics again.

**Files:**
- Modify: `lib/screens/home_screen.dart:122-123`
- Modify: `lib/widgets/profile_form/profile_form_dialog.dart:124-125, 278-279`

> Note: `unlock_code_section.dart` also receives a `KeyColorOption`. We don't change it here — that file is being replaced by `set_key_section.dart` in Task 10, which will use `keyColorForRender` from the start.

- [ ] **Step 2.1: Update `home_screen.dart`**

Locate the lines (currently around 122-123):

```dart
final keyStyle = keyStyleById(p.keyStyleId);
final keyColor = keyColorById(keyStyle, p.keyColorId);
```

Replace with:

```dart
final keyStyle = keyStyleById(p.keyStyleId);
final keyColor = keyColorForRender(keyStyle, p.keyColorId);
```

- [ ] **Step 2.2: Update `profile_form_dialog.dart` — `_scanUnlockCode` (line ~124-125)**

Locate:

```dart
final keyStyle = keyStyleById(_keyStyleId);
final keyColor = keyColorById(keyStyle, _keyColorId);
```

Replace with:

```dart
final keyStyle = keyStyleById(_keyStyleId);
final keyColor = keyColorForRender(keyStyle, _keyColorId);
```

- [ ] **Step 2.3: Update `profile_form_dialog.dart` — Set Key Builder (line ~278-279)**

Locate:

```dart
final ks = keyStyleById(_keyStyleId);
final kc = keyColorById(ks, _keyColorId);
```

Replace with:

```dart
final ks = keyStyleById(_keyStyleId);
final kc = keyColorForRender(ks, _keyColorId);
```

- [ ] **Step 2.4: Run the existing test suite to confirm no regressions**

Run: `flutter test`
Expected: PASS — all existing tests still green. Behavior is identical for all current profiles (none have a mismatched style/color pair yet).

- [ ] **Step 2.5: Commit**

```bash
git add lib/screens/home_screen.dart lib/widgets/profile_form/profile_form_dialog.dart
git commit -m "refactor: route key rendering through keyColorForRender"
```

---

## Task 3: `SpriteCarousel<T>` core — peek, tap-to-snap, drag-snap, selection callback

**Why now:** Build the smallest carousel that works (no loop, no transforms, no bob) so subsequent tasks layer behavior onto a working baseline.

**Files:**
- Create: `lib/widgets/profile_form/carousel/sprite_carousel.dart`
- Create: `test/widgets/profile_form/carousel/sprite_carousel_test.dart`

- [ ] **Step 3.1: Write failing core tests**

Create `test/widgets/profile_form/carousel/sprite_carousel_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_lockdown/widgets/profile_form/carousel/sprite_carousel.dart';

Widget _harness({
  required List<String> items,
  required int selectedIndex,
  required ValueChanged<int> onSelectedChanged,
  bool infiniteLoop = false,
  bool centerBob = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 360,
        height: 100,
        child: SpriteCarousel<String>(
          items: items,
          selectedIndex: selectedIndex,
          onSelectedChanged: onSelectedChanged,
          centerSize: 64,
          sideSize: 44,
          edgeSize: 28,
          cellGap: 8,
          peekCount: 5,
          infiniteLoop: infiniteLoop,
          centerBob: centerBob,
          bobAmplitude: 4,
          bobPeriod: const Duration(milliseconds: 1400),
          sideSquish: false,
          sideFade: false,
          centerBevel: false,
          itemBuilder: (_, item, __) => Text(item, key: ValueKey('cell-$item')),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders cells around the selected index', (tester) async {
    await tester.pumpWidget(_harness(
      items: const ['a', 'b', 'c', 'd', 'e'],
      selectedIndex: 2,
      onSelectedChanged: (_) {},
    ));
    await tester.pumpAndSettle();

    // The center cell is c; at minimum b/c/d should be in the tree.
    expect(find.byKey(const ValueKey('cell-b')), findsOneWidget);
    expect(find.byKey(const ValueKey('cell-c')), findsOneWidget);
    expect(find.byKey(const ValueKey('cell-d')), findsOneWidget);
  });

  testWidgets('tap on a side cell triggers onSelectedChanged after settle',
      (tester) async {
    int? lastSelected;
    await tester.pumpWidget(_harness(
      items: const ['a', 'b', 'c', 'd', 'e'],
      selectedIndex: 2,
      onSelectedChanged: (i) => lastSelected = i,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('cell-d')));
    await tester.pumpAndSettle();

    expect(lastSelected, 3);
  });

  testWidgets('drag-and-release snaps to the nearest cell and fires callback',
      (tester) async {
    int? lastSelected;
    await tester.pumpWidget(_harness(
      items: const ['a', 'b', 'c', 'd', 'e'],
      selectedIndex: 2,
      onSelectedChanged: (i) => lastSelected = i,
    ));
    await tester.pumpAndSettle();

    // Drag left enough to advance one page.
    await tester.drag(find.byType(SpriteCarousel<String>), const Offset(-80, 0));
    await tester.pumpAndSettle();

    expect(lastSelected, 3);
  });

  testWidgets('with infiniteLoop:false, scrolling past last index clamps',
      (tester) async {
    int? lastSelected;
    await tester.pumpWidget(_harness(
      items: const ['a', 'b'],
      selectedIndex: 1,
      onSelectedChanged: (i) => lastSelected = i,
      infiniteLoop: false,
    ));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(SpriteCarousel<String>), const Offset(-200, 0));
    await tester.pumpAndSettle();

    // Cannot advance past index 1.
    expect(lastSelected, anyOf(isNull, 1));
  });
}
```

- [ ] **Step 3.2: Run tests to verify they fail**

Run: `flutter test test/widgets/profile_form/carousel/sprite_carousel_test.dart`
Expected: FAIL — `SpriteCarousel` import unresolved.

- [ ] **Step 3.3: Implement the carousel core**

Create `lib/widgets/profile_form/carousel/sprite_carousel.dart`:

```dart
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
  int _initialPage = 0;

  @override
  void initState() {
    super.initState();
    _initialPage = widget.infiniteLoop
        ? widget.items.length * _loopOffset + widget.selectedIndex
        : widget.selectedIndex;
    _controller = PageController(
      viewportFraction: 1.0 / widget.peekCount,
      initialPage: _initialPage,
    );
    _controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant SpriteCarousel<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex && !_controller.position.isScrollingNotifier.value) {
      final target = widget.infiniteLoop
          ? widget.items.length * _loopOffset + widget.selectedIndex
          : widget.selectedIndex;
      _controller.jumpToPage(target);
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
    final isSettled = (page - page.round()).abs() < 0.01;
    if (!isSettled) return;
    if (_controller.position.isScrollingNotifier.value) return;

    final actualIndex = page.round() % widget.items.length;
    final positiveIndex = (actualIndex + widget.items.length) % widget.items.length;
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
            controller: _controller,
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
  final PageController controller;
  final VoidCallback onTap;
  final Widget child;

  const _CarouselCell({
    required this.pageIndex,
    required this.controller,
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
```

- [ ] **Step 3.4: Run tests to verify they pass**

Run: `flutter test test/widgets/profile_form/carousel/sprite_carousel_test.dart`
Expected: PASS — 4 tests passing. If a test fails because `selectedIndex` isn't getting reported on tap, ensure the listener fires after `animateToPage` completes; the helper waits via `pumpAndSettle`, so the listener's `isSettled` branch must trigger.

- [ ] **Step 3.5: Commit**

```bash
git add lib/widgets/profile_form/carousel/sprite_carousel.dart test/widgets/profile_form/carousel/sprite_carousel_test.dart
git commit -m "feat: add SpriteCarousel core with peek, tap-snap, drag-snap"
```

---

## Task 4: `SpriteCarousel` infinite loop wrap test + verification

**Why now:** Task 3 already wired `infiniteLoop` plumbing — this task adds an explicit test for the wrap behavior so it's locked down before transforms layer on top.

**Files:**
- Modify: `test/widgets/profile_form/carousel/sprite_carousel_test.dart`

- [ ] **Step 4.1: Add infinite-loop wrap test**

Append to the `main()` body in `sprite_carousel_test.dart`:

```dart
  testWidgets('with infiniteLoop:true, scrolling backward from index 0 wraps',
      (tester) async {
    int? lastSelected;
    await tester.pumpWidget(_harness(
      items: const ['a', 'b', 'c'],
      selectedIndex: 0,
      onSelectedChanged: (i) => lastSelected = i,
      infiniteLoop: true,
    ));
    await tester.pumpAndSettle();

    // Drag right to go backward.
    await tester.drag(find.byType(SpriteCarousel<String>), const Offset(80, 0));
    await tester.pumpAndSettle();

    // Should wrap to index 2 (last).
    expect(lastSelected, 2);
  });

  testWidgets('with infiniteLoop:true, scrolling past the last index wraps',
      (tester) async {
    int? lastSelected;
    await tester.pumpWidget(_harness(
      items: const ['a', 'b', 'c'],
      selectedIndex: 2,
      onSelectedChanged: (i) => lastSelected = i,
      infiniteLoop: true,
    ));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(SpriteCarousel<String>), const Offset(-80, 0));
    await tester.pumpAndSettle();

    expect(lastSelected, 0);
  });
```

- [ ] **Step 4.2: Run tests**

Run: `flutter test test/widgets/profile_form/carousel/sprite_carousel_test.dart`
Expected: PASS — 6 tests now.

- [ ] **Step 4.3: Commit**

```bash
git add test/widgets/profile_form/carousel/sprite_carousel_test.dart
git commit -m "test: cover SpriteCarousel infinite-loop wrap behavior"
```

---

## Task 5: `SpriteCarousel` per-page transforms (scale + opacity + horizontal squish)

**Why now:** Visual transforms are the load-bearing "3D feel" — must be wired into `_CarouselCell` and verified to render the center cell larger than side cells.

**Files:**
- Modify: `lib/widgets/profile_form/carousel/sprite_carousel.dart`
- Modify: `test/widgets/profile_form/carousel/sprite_carousel_test.dart`

- [ ] **Step 5.1: Write a failing test that asserts the center cell is larger than side cells**

Append to `main()` in `sprite_carousel_test.dart`:

```dart
  testWidgets('center cell scales larger than side cells', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          height: 100,
          child: SpriteCarousel<String>(
            items: const ['a', 'b', 'c', 'd', 'e'],
            selectedIndex: 2,
            onSelectedChanged: (_) {},
            centerSize: 64,
            sideSize: 44,
            edgeSize: 28,
            cellGap: 8,
            peekCount: 5,
            infiniteLoop: false,
            centerBob: false,
            bobAmplitude: 0,
            bobPeriod: const Duration(milliseconds: 1400),
            sideSquish: true,
            sideFade: true,
            centerBevel: false,
            itemBuilder: (_, item, centerness) => SizedBox(
              key: ValueKey('cell-$item'),
              width: 64,
              height: 64,
              child: Center(child: Text(item)),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final centerSize = tester.getSize(find.byKey(const ValueKey('cell-c')));
    final sideSize = tester.getSize(find.byKey(const ValueKey('cell-b')));
    expect(centerSize.height, greaterThan(sideSize.height));
  });
```

- [ ] **Step 5.2: Run test to verify it fails**

Run: `flutter test test/widgets/profile_form/carousel/sprite_carousel_test.dart -p chrome --plain-name "scales larger"` (or just run all and look for the new failure)
Expected: FAIL — without transforms, all cells are the same size.

- [ ] **Step 5.3: Implement per-page transforms**

Replace `_CarouselCell` in `sprite_carousel.dart` with a transform-applying version. Also pass through `sideSquish`, `sideFade`, and the cell's "centerness" to `widget.itemBuilder`:

```dart
class _CarouselCell extends StatelessWidget {
  final int pageIndex;
  final PageController controller;
  final VoidCallback onTap;
  final double centerSize;
  final double sideSize;
  final double edgeSize;
  final bool sideSquish;
  final bool sideFade;
  final Widget Function(double centerness) builder;

  const _CarouselCell({
    required this.pageIndex,
    required this.controller,
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
      animation: controller,
      builder: (context, _) {
        final page = controller.hasClients && controller.position.haveDimensions
            ? (controller.page ?? pageIndex.toDouble())
            : pageIndex.toDouble();
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
        final scale = targetSize / centerSize;

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

        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: Opacity(
              opacity: opacity,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..scale(scale * xScale, scale, 1.0),
                child: builder(centerness),
              ),
            ),
          ),
        );
      },
    );
  }
}
```

Update the call in `build` of `_SpriteCarouselState` to use the new constructor and pass the builder:

```dart
            itemBuilder: (context, pageIndex) {
              final itemIndex = _itemIndexForPage(pageIndex);
              final item = widget.items[itemIndex];
              return _CarouselCell(
                pageIndex: pageIndex,
                controller: _controller,
                onTap: () => _animateToPage(pageIndex),
                centerSize: widget.centerSize,
                sideSize: widget.sideSize,
                edgeSize: widget.edgeSize,
                sideSquish: widget.sideSquish,
                sideFade: widget.sideFade,
                builder: (centerness) =>
                    widget.itemBuilder(context, item, centerness),
              );
            },
```

- [ ] **Step 5.4: Run tests to verify all pass**

Run: `flutter test test/widgets/profile_form/carousel/sprite_carousel_test.dart`
Expected: PASS — 7 tests now.

- [ ] **Step 5.5: Commit**

```bash
git add lib/widgets/profile_form/carousel/sprite_carousel.dart test/widgets/profile_form/carousel/sprite_carousel_test.dart
git commit -m "feat: SpriteCarousel scales, fades, and squishes side cells"
```

---

## Task 6: `SpriteCarousel` center bob animation

**Why now:** Bob is independent of selection; layering it after transforms means the center cell already has the right anchor for translation.

**Files:**
- Modify: `lib/widgets/profile_form/carousel/sprite_carousel.dart`
- Modify: `test/widgets/profile_form/carousel/sprite_carousel_test.dart`

- [ ] **Step 6.1: Write a failing test asserting bob applies vertical translation only when `centerBob: true`**

Append to `main()`:

```dart
  testWidgets('centerBob applies a vertical translation to the center cell',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          height: 120,
          child: SpriteCarousel<String>(
            items: const ['a', 'b', 'c'],
            selectedIndex: 1,
            onSelectedChanged: (_) {},
            centerSize: 64,
            sideSize: 44,
            edgeSize: 28,
            cellGap: 8,
            peekCount: 3,
            infiniteLoop: false,
            centerBob: true,
            bobAmplitude: 4,
            bobPeriod: const Duration(milliseconds: 400),
            sideSquish: false,
            sideFade: false,
            centerBevel: false,
            itemBuilder: (_, item, __) => SizedBox(
              key: ValueKey('cell-$item'),
              width: 32,
              height: 32,
              child: Text(item),
            ),
          ),
        ),
      ),
    ));
    // Pump partway through the bob period to a moment where sin(t) is non-zero.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100)); // ~quarter period

    final centerY1 = tester.getTopLeft(find.byKey(const ValueKey('cell-b'))).dy;
    await tester.pump(const Duration(milliseconds: 200));
    final centerY2 = tester.getTopLeft(find.byKey(const ValueKey('cell-b'))).dy;

    // The center cell's dy must change between two animation frames if bob is on.
    expect(centerY1, isNot(centerY2));
  });
```

- [ ] **Step 6.2: Run test, verify it fails**

Run: `flutter test test/widgets/profile_form/carousel/sprite_carousel_test.dart`
Expected: FAIL — center cell is static.

- [ ] **Step 6.3: Implement bob**

In `sprite_carousel.dart`, add a `SingleTickerProviderStateMixin` to the state class and a bob controller:

Replace the state class declaration and `initState`/`dispose`:

```dart
class _SpriteCarouselState<T> extends State<SpriteCarousel<T>>
    with SingleTickerProviderStateMixin {
  static const int _loopOffset = 1000;

  late PageController _controller;
  int _initialPage = 0;
  late AnimationController _bobController;

  @override
  void initState() {
    super.initState();
    _initialPage = widget.infiniteLoop
        ? widget.items.length * _loopOffset + widget.selectedIndex
        : widget.selectedIndex;
    _controller = PageController(
      viewportFraction: 0.25,
      initialPage: _initialPage,
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
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    _bobController.dispose();
    super.dispose();
  }
```

In the `itemBuilder`, pass the bob controller into `_CarouselCell`:

```dart
              return _CarouselCell(
                pageIndex: pageIndex,
                controller: _controller,
                bobController: _bobController,
                bobAmplitude: widget.centerBob ? widget.bobAmplitude : 0,
                onTap: () => _animateToPage(pageIndex),
                centerSize: widget.centerSize,
                sideSize: widget.sideSize,
                edgeSize: widget.edgeSize,
                sideSquish: widget.sideSquish,
                sideFade: widget.sideFade,
                builder: (centerness) =>
                    widget.itemBuilder(context, item, centerness),
              );
```

In `_CarouselCell`, accept the bob controller and apply its translation. Wrap the existing `Transform` with a translation `Transform`:

```dart
import 'dart:math' as math;

class _CarouselCell extends StatelessWidget {
  final int pageIndex;
  final PageController controller;
  final AnimationController bobController;
  final double bobAmplitude;
  final VoidCallback onTap;
  final double centerSize;
  final double sideSize;
  final double edgeSize;
  final bool sideSquish;
  final bool sideFade;
  final Widget Function(double centerness) builder;

  const _CarouselCell({
    required this.pageIndex,
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
            ? (controller.page ?? pageIndex.toDouble())
            : pageIndex.toDouble();
        final dRaw = (page - pageIndex).abs();
        final d = dRaw.clamp(0.0, 2.0);
        final centerness = (1.0 - d).clamp(0.0, 1.0);

        final double targetSize;
        if (d <= 1.0) {
          targetSize = centerSize + (sideSize - centerSize) * d;
        } else {
          targetSize = sideSize + (edgeSize - sideSize) * (d - 1.0);
        }
        final scale = targetSize / centerSize;

        double opacity = 1.0;
        if (sideFade) {
          if (d <= 1.0) {
            opacity = 1.0 - 0.3 * d;
          } else {
            opacity = 0.7 - 0.3 * (d - 1.0);
          }
        }

        double xScale = 1.0;
        if (sideSquish) {
          xScale = 1.0 - 0.15 * d.clamp(0.0, 1.0) - 0.15 * (d - 1.0).clamp(0.0, 1.0);
        }

        // Bob: only the center-most cell actually moves; weight by centerness.
        final bobDy = bobAmplitude > 0
            ? (-bobAmplitude * math.sin(bobController.value * 2 * math.pi) * centerness)
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
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..scale(scale * xScale, scale, 1.0),
                  child: builder(centerness),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 6.4: Run tests**

Run: `flutter test test/widgets/profile_form/carousel/sprite_carousel_test.dart`
Expected: PASS — 8 tests now.

- [ ] **Step 6.5: Commit**

```bash
git add lib/widgets/profile_form/carousel/sprite_carousel.dart test/widgets/profile_form/carousel/sprite_carousel_test.dart
git commit -m "feat: SpriteCarousel center bob animation"
```

---

## Task 7: `SpriteCarousel` haptics + reduced-motion support

**Why now:** Behavioral polish. Easier to add now while the carousel internals are fresh than to retrofit after the wrappers depend on them.

**Files:**
- Modify: `lib/widgets/profile_form/carousel/sprite_carousel.dart`

> Note: haptics aren't testable in `flutter_test` without mocking the platform channel. We'll verify on-device in Task 12. Reduced motion is asserted via test.

- [ ] **Step 7.1: Add `HapticFeedback` call in `_onScroll`**

In `sprite_carousel.dart`, add this import at the top:

```dart
import 'package:flutter/services.dart';
```

Update `_onScroll` to fire haptics on a real selection change:

```dart
  void _onScroll() {
    final page = _controller.page;
    if (page == null) return;
    final isSettled = (page - page.round()).abs() < 0.01;
    if (!isSettled) return;
    if (_controller.position.isScrollingNotifier.value) return;

    final actualIndex = page.round() % widget.items.length;
    final positiveIndex = (actualIndex + widget.items.length) % widget.items.length;
    if (positiveIndex != widget.selectedIndex) {
      HapticFeedback.selectionClick();
      widget.onSelectedChanged(positiveIndex);
    }
  }
```

- [ ] **Step 7.2: Add reduced-motion handling**

In `_SpriteCarouselState.build`, read `MediaQuery.disableAnimationsOf(context)` and conditionally suppress the bob and shorten snap. Update the `_animateToPage` and the bob controller setup:

Replace `_animateToPage`:

```dart
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
```

And in `build`, before constructing the `PageView`, gate the bob controller:

```dart
        final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
        if (reduce && _bobController.isAnimating) {
          _bobController.stop();
          _bobController.value = 0;
        } else if (!reduce && widget.centerBob && widget.bobAmplitude > 0 && !_bobController.isAnimating) {
          _bobController.repeat();
        }
```

- [ ] **Step 7.3: Add a reduced-motion test**

Append to `main()` in the carousel test file:

```dart
  testWidgets('reduced motion stops the bob and uses jumpToPage',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(
          body: SizedBox(
            width: 360,
            height: 120,
            child: SpriteCarousel<String>(
              items: const ['a', 'b', 'c'],
              selectedIndex: 1,
              onSelectedChanged: (_) {},
              centerSize: 64,
              sideSize: 44,
              edgeSize: 28,
              cellGap: 8,
              peekCount: 3,
              infiniteLoop: false,
              centerBob: true,
              bobAmplitude: 4,
              bobPeriod: const Duration(milliseconds: 400),
              sideSquish: false,
              sideFade: false,
              centerBevel: false,
              itemBuilder: (_, item, __) => SizedBox(
                key: ValueKey('cell-$item'),
                width: 32,
                height: 32,
                child: Text(item),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final y1 = tester.getTopLeft(find.byKey(const ValueKey('cell-b'))).dy;
    await tester.pump(const Duration(milliseconds: 200));
    final y2 = tester.getTopLeft(find.byKey(const ValueKey('cell-b'))).dy;
    expect(y1, y2); // Bob frozen.
  });
```

- [ ] **Step 7.4: Run all carousel tests**

Run: `flutter test test/widgets/profile_form/carousel/sprite_carousel_test.dart`
Expected: PASS — 9 tests now.

- [ ] **Step 7.5: Commit**

```bash
git add lib/widgets/profile_form/carousel/sprite_carousel.dart test/widgets/profile_form/carousel/sprite_carousel_test.dart
git commit -m "feat: SpriteCarousel haptics + reduced-motion support"
```

---

## Task 8: `KeyStyleCarousel` widget

**Files:**
- Create: `lib/widgets/profile_form/carousel/key_style_carousel.dart`
- Create: `test/widgets/profile_form/carousel/key_style_carousel_test.dart`

- [ ] **Step 8.1: Write failing tests for the wrapper**

Create `test/widgets/profile_form/carousel/key_style_carousel_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_lockdown/customization/key_catalog.dart';
import 'package:phone_lockdown/widgets/profile_form/carousel/key_style_carousel.dart';
import 'package:phone_lockdown/widgets/sprite_sheet.dart';

void main() {
  testWidgets('renders an AnimatedSprite for every visible animated style',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          height: 100,
          child: KeyStyleCarousel(
            selectedStyleId: 'key_4', // animated
            selectedColorId: 'gold',
            onStyleChanged: (_) {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // At least one AnimatedSprite mounted (center is animated).
    expect(find.byType(AnimatedSprite), findsWidgets);
  });

  testWidgets(
      'when saved color is unsupported, the rendered asset path uses grey',
      (tester) async {
    String? lastTriggeredId;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          height: 100,
          child: KeyStyleCarousel(
            selectedStyleId: 'key_4', // does not support curse
            selectedColorId: 'curse',
            onStyleChanged: (id) => lastTriggeredId = id,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Find any AnimatedSprite and confirm its assetPath ends with _grey.png.
    final sprite = tester.widget<AnimatedSprite>(find.byType(AnimatedSprite).first);
    expect(sprite.assetPath, endsWith('_grey.png'));
    expect(lastTriggeredId, isNull);
  });
}
```

- [ ] **Step 8.2: Run tests, verify they fail**

Run: `flutter test test/widgets/profile_form/carousel/key_style_carousel_test.dart`
Expected: FAIL — `KeyStyleCarousel` doesn't exist.

- [ ] **Step 8.3: Implement `KeyStyleCarousel`**

Create `lib/widgets/profile_form/carousel/key_style_carousel.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../customization/key_catalog.dart';
import '../../sprite_sheet.dart';
import 'sprite_carousel.dart';

class KeyStyleCarousel extends StatelessWidget {
  static const Duration _spriteAnimationDuration = Duration(milliseconds: 1200);

  final String selectedStyleId;
  final String selectedColorId;
  final ValueChanged<String> onStyleChanged;

  const KeyStyleCarousel({
    super.key,
    required this.selectedStyleId,
    required this.selectedColorId,
    required this.onStyleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedIndex =
        kKeyCatalog.indexWhere((s) => s.id == selectedStyleId).clamp(0, kKeyCatalog.length - 1);

    return SpriteCarousel<KeyStyle>(
      items: kKeyCatalog,
      selectedIndex: selectedIndex,
      onSelectedChanged: (i) => onStyleChanged(kKeyCatalog[i].id),
      centerSize: 64,
      sideSize: 44,
      edgeSize: 28,
      cellGap: 8,
      peekCount: 5,
      infiniteLoop: true,
      centerBob: true,
      bobAmplitude: 4,
      bobPeriod: const Duration(milliseconds: 1400),
      sideSquish: true,
      sideFade: true,
      centerBevel: false,
      itemBuilder: (context, style, centerness) {
        final renderColorId = renderColorIdFor(style, selectedColorId);
        final assetPath = style.spritesheetPath(renderColorId);
        if (style.animated) {
          return AnimatedSprite(
            key: ValueKey('keycar-${style.id}-$renderColorId'),
            assetPath: assetPath,
            frameWidth: style.frameWidth,
            frameHeight: style.frameHeight,
            frameCount: style.frameCount,
            startFrame: 0,
            endFrame: style.frameCount - 1,
            duration: _spriteAnimationDuration,
            loop: true,
            size: 44,
          );
        }
        return SpriteFrame(
          key: ValueKey('keycar-${style.id}-$renderColorId-static'),
          assetPath: assetPath,
          frameWidth: style.frameWidth,
          frameHeight: style.frameHeight,
          frameIndex: 0,
          size: 44,
        );
      },
    );
  }
}
```

- [ ] **Step 8.4: Run tests**

Run: `flutter test test/widgets/profile_form/carousel/key_style_carousel_test.dart`
Expected: PASS — 2 tests.

- [ ] **Step 8.5: Commit**

```bash
git add lib/widgets/profile_form/carousel/key_style_carousel.dart test/widgets/profile_form/carousel/key_style_carousel_test.dart
git commit -m "feat: KeyStyleCarousel — keys-flavored SpriteCarousel wrapper"
```

---

## Task 9: `KeyColorCarousel` widget

**Files:**
- Create: `lib/widgets/profile_form/carousel/key_color_carousel.dart`
- Create: `test/widgets/profile_form/carousel/key_color_carousel_test.dart`

- [ ] **Step 9.1: Write failing tests**

Create `test/widgets/profile_form/carousel/key_color_carousel_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_lockdown/customization/key_catalog.dart';
import 'package:phone_lockdown/widgets/profile_form/carousel/key_color_carousel.dart';
import 'package:phone_lockdown/widgets/sprite_sheet.dart';

void main() {
  testWidgets('renders one cell per color of the active style', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          height: 80,
          child: KeyColorCarousel(
            selectedStyleId: 'key_4', // 4 standard colors
            selectedColorId: 'gold',
            onColorChanged: (_) {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Expect SpriteFrames for each visible swatch (page lazy-loads, so count >=1).
    expect(find.byType(SpriteFrame), findsWidgets);
  });

  testWidgets(
      'with unsupported saved color, does not call onColorChanged on build',
      (tester) async {
    String? mutated;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          height: 80,
          child: KeyColorCarousel(
            selectedStyleId: 'key_4',
            selectedColorId: 'curse', // not in key_4's colors
            onColorChanged: (id) => mutated = id,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(mutated, isNull);
  });

  testWidgets('reshapes when selectedStyleId changes from key_4 to key_8',
      (tester) async {
    String styleId = 'key_4';
    String colorId = 'gold';
    await tester.pumpWidget(StatefulBuilder(builder: (context, setState) {
      return MaterialApp(
        home: Scaffold(
          body: Column(children: [
            SizedBox(
              width: 360,
              height: 80,
              child: KeyColorCarousel(
                selectedStyleId: styleId,
                selectedColorId: colorId,
                onColorChanged: (id) => setState(() => colorId = id),
              ),
            ),
            ElevatedButton(
              onPressed: () => setState(() => styleId = 'key_8'),
              child: const Text('switch'),
            ),
          ]),
        ),
      );
    }));
    await tester.pumpAndSettle();
    final initialColorIds = keyStyleById('key_4').colors.map((c) => c.id).toList();
    expect(initialColorIds, containsAll(['gold', 'silver', 'bronze', 'grey']));

    await tester.tap(find.text('switch'));
    await tester.pumpAndSettle();

    final newColorIds = keyStyleById('key_8').colors.map((c) => c.id).toList();
    expect(newColorIds, containsAll(['gold', 'silver', 'grey', 'curse']));
    expect(newColorIds.contains('bronze'), isFalse);
  });
}
```

- [ ] **Step 9.2: Run tests, verify they fail**

Run: `flutter test test/widgets/profile_form/carousel/key_color_carousel_test.dart`
Expected: FAIL — `KeyColorCarousel` undefined.

- [ ] **Step 9.3: Implement `KeyColorCarousel`**

Create `lib/widgets/profile_form/carousel/key_color_carousel.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../customization/key_catalog.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/bevel.dart';
import '../../sprite_sheet.dart';
import 'sprite_carousel.dart';

class KeyColorCarousel extends StatelessWidget {
  final String selectedStyleId;
  final String selectedColorId;
  final ValueChanged<String> onColorChanged;

  const KeyColorCarousel({
    super.key,
    required this.selectedStyleId,
    required this.selectedColorId,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    final style = keyStyleById(selectedStyleId);
    final colors = style.colors;
    final selectedIndex = colorCenterIndex(style, selectedColorId);

    return SpriteCarousel<KeyColorOption>(
      items: colors,
      selectedIndex: selectedIndex,
      onSelectedChanged: (i) => onColorChanged(colors[i].id),
      centerSize: 44,
      sideSize: 44,
      edgeSize: 44,
      cellGap: 12,
      peekCount: 3,
      infiniteLoop: false,
      centerBob: false,
      bobAmplitude: 0,
      bobPeriod: const Duration(milliseconds: 1),
      sideSquish: false,
      sideFade: false,
      centerBevel: true,
      itemBuilder: (context, color, centerness) {
        final isCenter = centerness > 0.5;
        return Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: isCenter
              ? Bevel.raised(fill: AppColors.surfaceContainerHigh)
              : Bevel.ghost(
                  fill: AppColors.surfaceContainerLow,
                  opacity: 0.4,
                ),
          child: SpriteFrame(
            assetPath: style.spritesheetPath(color.id),
            frameWidth: style.frameWidth,
            frameHeight: style.frameHeight,
            frameIndex: 0,
            size: 36,
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 9.4: Run tests**

Run: `flutter test test/widgets/profile_form/carousel/key_color_carousel_test.dart`
Expected: PASS — 3 tests.

- [ ] **Step 9.5: Commit**

```bash
git add lib/widgets/profile_form/carousel/key_color_carousel.dart test/widgets/profile_form/carousel/key_color_carousel_test.dart
git commit -m "feat: KeyColorCarousel — colors-flavored SpriteCarousel wrapper"
```

---

## Task 10: `SetKeySection` — replace `unlock_code_section.dart`

**Why now:** With both carousels working, we can compose them with the existing code/QR row into the new Set Key block.

**Files:**
- Create: `lib/widgets/profile_form/set_key_section.dart`
- Delete: `lib/widgets/profile_form/unlock_code_section.dart`

- [ ] **Step 10.1: Create `set_key_section.dart`**

Create `lib/widgets/profile_form/set_key_section.dart` (this is the same code/QR row as before, plus the two carousels stacked beneath):

```dart
import 'package:flutter/material.dart';
import '../../customization/key_catalog.dart';
import '../../theme/app_colors.dart';
import '../../theme/bevel.dart';
import '../key_display.dart';
import 'carousel/key_color_carousel.dart';
import 'carousel/key_style_carousel.dart';

class SetKeySection extends StatelessWidget {
  final String? unlockCode;
  final VoidCallback onScan;
  final VoidCallback onClear;
  final String selectedStyleId;
  final String selectedColorId;
  final ValueChanged<String> onStyleChanged;
  final ValueChanged<String> onColorChanged;

  const SetKeySection({
    super.key,
    required this.unlockCode,
    required this.onScan,
    required this.onClear,
    required this.selectedStyleId,
    required this.selectedColorId,
    required this.onStyleChanged,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    final style = keyStyleById(selectedStyleId);
    final color = keyColorForRender(style, selectedColorId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SET KEY',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: Bevel.sunken(fill: AppColors.surfaceContainerLowest),
          child: Row(
            children: [
              if (unlockCode != null)
                SizedBox(
                  height: 32,
                  width: 32,
                  child: Center(
                    child: KeyDisplay(
                      style: style,
                      color: color,
                      size: 28,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.vpn_key_off,
                  size: 20,
                  color: AppColors.outline,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  unlockCode != null
                      ? '${unlockCode!.substring(0, unlockCode!.length.clamp(0, 12))}...'
                      : 'No code set',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: unlockCode != null
                        ? AppColors.onSurface
                        : AppColors.outline,
                  ),
                ),
              ),
              if (unlockCode != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: AppColors.outline),
                  onPressed: onClear,
                  tooltip: 'Clear code',
                ),
              Container(
                decoration: Bevel.raised(fill: AppColors.primaryContainer),
                child: IconButton(
                  icon: const Icon(
                    Icons.qr_code_scanner,
                    size: 20,
                    color: AppColors.onPrimaryContainer,
                  ),
                  onPressed: onScan,
                  tooltip: 'Scan code',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        KeyStyleCarousel(
          selectedStyleId: selectedStyleId,
          selectedColorId: selectedColorId,
          onStyleChanged: onStyleChanged,
        ),
        const SizedBox(height: 12),
        KeyColorCarousel(
          selectedStyleId: selectedStyleId,
          selectedColorId: selectedColorId,
          onColorChanged: onColorChanged,
        ),
      ],
    );
  }
}
```

- [ ] **Step 10.2: Delete `unlock_code_section.dart`**

```bash
git rm lib/widgets/profile_form/unlock_code_section.dart
```

(The file is being replaced — `set_key_section.dart` is its functional successor.)

- [ ] **Step 10.3: Run the full test suite (everything except dialog wiring should compile, but dialog still imports the old file)**

The dialog will fail to compile because it still imports `unlock_code_section.dart`. That's expected — Task 11 fixes it. Skip running tests until then to avoid noise; just verify the new file analyzes:

Run: `dart analyze lib/widgets/profile_form/set_key_section.dart`
Expected: No errors specific to this file (only ones reported elsewhere, e.g., `profile_form_dialog.dart` referencing the deleted import).

- [ ] **Step 10.4: Commit**

```bash
git add lib/widgets/profile_form/set_key_section.dart
git commit -m "feat: SetKeySection — code row + style carousel + color carousel"
```

---

## Task 11: Wire `SetKeySection` into `ProfileFormDialog`, drop standalone Key picker

**Why now:** Last code change. Restores the build, removes `key_picker.dart`, simplifies `_onKeyStyleChanged`.

**Files:**
- Modify: `lib/widgets/profile_form/profile_form_dialog.dart`
- Delete: `lib/widgets/profile_form/key_picker.dart`

- [ ] **Step 11.1: Replace imports in `profile_form_dialog.dart`**

In `lib/widgets/profile_form/profile_form_dialog.dart`, replace:

```dart
import 'key_picker.dart';
import 'lock_picker.dart';
import 'unlock_code_section.dart';
```

with:

```dart
import 'lock_picker.dart';
import 'set_key_section.dart';
```

- [ ] **Step 11.2: Simplify `_onKeyStyleChanged`**

Replace the existing `_onKeyStyleChanged` (lines ~71-79):

```dart
  void _onKeyStyleChanged(String id) {
    setState(() {
      _keyStyleId = id;
      final available = keyStyleById(id).colors;
      if (!available.any((c) => c.id == _keyColorId)) {
        _keyColorId = available.first.id;
      }
    });
  }
```

with:

```dart
  void _onKeyStyleChanged(String id) {
    setState(() => _keyStyleId = id);
  }
```

- [ ] **Step 11.3: Replace the Set Key container body and remove the standalone Key picker container**

Find the Set Key section in `build`:

```dart
          // Set Key section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: Bevel.ghost(
              fill: AppColors.surfaceContainerLow,
              opacity: 0.2,
            ),
            child: Builder(builder: (_) {
              final ks = keyStyleById(_keyStyleId);
              final kc = keyColorForRender(ks, _keyColorId);
              return UnlockCodeSection(
                unlockCode: _unlockCode,
                onScan: _scanUnlockCode,
                onClear: () => setState(() => _unlockCode = null),
                keyStyle: ks,
                keyColor: kc,
              );
            }),
          ),
```

Replace its body with:

```dart
          // Set Key section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: Bevel.ghost(
              fill: AppColors.surfaceContainerLow,
              opacity: 0.2,
            ),
            child: SetKeySection(
              unlockCode: _unlockCode,
              onScan: _scanUnlockCode,
              onClear: () => setState(() => _unlockCode = null),
              selectedStyleId: _keyStyleId,
              selectedColorId: _keyColorId,
              onStyleChanged: _onKeyStyleChanged,
              onColorChanged: (id) => setState(() => _keyColorId = id),
            ),
          ),
```

Remove the now-redundant standalone "Key picker section" container entirely (lines ~307-320 — the block that wraps `KeyStyleColorPicker` in a `Container(...Bevel.ghost...)` and is followed by `const SizedBox(height: 16)`). Delete that container **and** its trailing `SizedBox(height: 16)`.

- [ ] **Step 11.4: Delete `key_picker.dart`**

```bash
git rm lib/widgets/profile_form/key_picker.dart
```

- [ ] **Step 11.5: Run the full test suite**

Run: `flutter test`
Expected: PASS — all carousel tests + existing tests (`widget_test.dart`, `profile_manager_test.dart`, `app_blocker_service_test.dart`) green. No imports unresolved.

- [ ] **Step 11.6: Run static analysis**

Run: `dart analyze`
Expected: No errors. There may be pre-existing warnings unrelated to this change — leave those alone.

- [ ] **Step 11.7: Commit**

```bash
git add lib/widgets/profile_form/profile_form_dialog.dart
git commit -m "feat: replace key picker with SetKeySection carousels in profile form"
```

---

## Task 12: On-device verification + push

**Why now:** Every UI change must be visually validated on a real device per `CLAUDE.md`. Carousel feel (momentum, snap, bob amplitude, haptics) only reads correctly under finger.

**Files:** none — this is a manual / device pass.

- [ ] **Step 12.1: Confirm an Android device is connected**

Run: `adb devices`
Expected: at least one device listed as `device` (not `unauthorized`/`offline`). If none is connected, skip the device pass and document in commit message. Otherwise continue.

- [ ] **Step 12.2: Build and install**

Run: `cd android && ./gradlew installDebug && cd ..`
Expected: `BUILD SUCCESSFUL`. The app installs and launches without runtime errors.

- [ ] **Step 12.3: Visual verification checklist**

Open the app → New Profile (or Edit an existing one). In the Set Key section, verify:

- The standalone "Key" section below Lock is **gone**.
- Set Key now contains: code/QR row → style carousel → color carousel.
- Style carousel: 5 cells visible, center is largest, sides scale down and fade. Animated keys (key_2, key_4, key_5, …) play their sprite animations even when off-center.
- Center key has a clear vertical bob (~4 px, ~1.4 s period). Side keys do not bob.
- Drag-fling: momentum, snaps to a key on settle. Haptic tick on each settled snap.
- Tap a side cell: it slides to center.
- Scroll backward from key_4 (the default first item): wraps to key_15 (infinite loop).
- Scroll backward at key_15 → wraps to key_4.
- Color carousel: 3 cells visible, all the same size. Tap or drag changes color. No bob. Bounces at ends (try dragging past first/last swatch — does not wrap).
- Pick **curse** while on **key_8**, then scroll the style carousel: every other key in the carousel renders in **grey**. Color carousel reshapes to `[gold, silver, bronze, grey]` and centers on `grey`. The saved `curse` is honored when you scroll back to `key_8`.
- Save the profile, return to the home screen — the profile cell shows the saved key (in grey for non-`key_8` styles when curse is the saved color).
- Toggle Settings → Accessibility → "Remove animations" (or equivalent on the device's Android version). Open the profile form: bob is frozen, snap is instantaneous. Animations on the sprite content itself still play (they are content, not chrome).

- [ ] **Step 12.4: Push to GitHub**

```bash
git push
```

- [ ] **Step 12.5: Final summary commit (only if Step 12.3 found a tunable that needs adjustment, e.g., bob amplitude feels off)**

If everything looks right, no extra commit needed. If something needs a tweak (e.g., 4 px bob feels too subtle and needs to be 5 px), make the targeted edit and commit:

```bash
git add <path>
git commit -m "tune: <what changed and why, one line>"
git push
```

---

## Plan summary

12 tasks. Approximate ordering of risk: helpers (low) → render-site migration (low) → carousel core (medium) → carousel transforms (medium) → carousel bob (low) → polish (low) → wrappers (low) → integration (low) → device pass (validates the whole thing). Tests precede every implementation step. Each task ends in a commit so the history is bisectable.
