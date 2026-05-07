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
