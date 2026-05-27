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
          itemBuilder: (_, item, _, _) =>
              Text(item, key: ValueKey('cell-$item')),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders cells around the selected index', (tester) async {
    await tester.pumpWidget(
      _harness(
        items: const ['a', 'b', 'c', 'd', 'e'],
        selectedIndex: 2,
        onSelectedChanged: (_) {},
      ),
    );
    await tester.pumpAndSettle();

    // The center cell is c; at minimum b/c/d should be in the tree.
    expect(find.byKey(const ValueKey('cell-b')), findsOneWidget);
    expect(find.byKey(const ValueKey('cell-c')), findsOneWidget);
    expect(find.byKey(const ValueKey('cell-d')), findsOneWidget);
  });

  testWidgets('tap on a side cell triggers onSelectedChanged after settle', (
    tester,
  ) async {
    int? lastSelected;
    await tester.pumpWidget(
      _harness(
        items: const ['a', 'b', 'c', 'd', 'e'],
        selectedIndex: 2,
        onSelectedChanged: (i) => lastSelected = i,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('cell-d')));
    await tester.pumpAndSettle();

    expect(lastSelected, 3);
  });

  testWidgets('drag-and-release snaps to the nearest cell and fires callback', (
    tester,
  ) async {
    int? lastSelected;
    await tester.pumpWidget(
      _harness(
        items: const ['a', 'b', 'c', 'd', 'e'],
        selectedIndex: 2,
        onSelectedChanged: (i) => lastSelected = i,
      ),
    );
    await tester.pumpAndSettle();

    // Drag left enough to advance one page.
    await tester.drag(
      find.byType(SpriteCarousel<String>),
      const Offset(-80, 0),
    );
    await tester.pumpAndSettle();

    expect(lastSelected, 3);
  });

  testWidgets('with infiniteLoop:false, scrolling past last index clamps', (
    tester,
  ) async {
    int? lastSelected;
    await tester.pumpWidget(
      _harness(
        items: const ['a', 'b'],
        selectedIndex: 1,
        onSelectedChanged: (i) => lastSelected = i,
        infiniteLoop: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(SpriteCarousel<String>),
      const Offset(-200, 0),
    );
    await tester.pumpAndSettle();

    // Cannot advance past index 1.
    expect(lastSelected, anyOf(isNull, 1));
  });

  testWidgets('with infiniteLoop:true, scrolling backward from index 0 wraps', (
    tester,
  ) async {
    int? lastSelected;
    await tester.pumpWidget(
      _harness(
        items: const ['a', 'b', 'c'],
        selectedIndex: 0,
        onSelectedChanged: (i) => lastSelected = i,
        infiniteLoop: true,
      ),
    );
    await tester.pumpAndSettle();

    // Drag right to go backward.
    await tester.drag(find.byType(SpriteCarousel<String>), const Offset(80, 0));
    await tester.pumpAndSettle();

    // Should wrap to index 2 (last).
    expect(lastSelected, 2);
  });

  testWidgets('with infiniteLoop:true, scrolling past the last index wraps', (
    tester,
  ) async {
    int? lastSelected;
    await tester.pumpWidget(
      _harness(
        items: const ['a', 'b', 'c'],
        selectedIndex: 2,
        onSelectedChanged: (i) => lastSelected = i,
        infiniteLoop: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(SpriteCarousel<String>),
      const Offset(-80, 0),
    );
    await tester.pumpAndSettle();

    expect(lastSelected, 0);
  });

  testWidgets('centerBob applies a vertical translation to the center cell', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
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
              itemBuilder: (_, item, _, _) => SizedBox(
                key: ValueKey('cell-$item'),
                width: 32,
                height: 32,
                child: Text(item),
              ),
            ),
          ),
        ),
      ),
    );
    // Pump partway through the bob period to a moment where sin(t) is non-zero.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100)); // ~quarter period

    final centerY1 = tester.getTopLeft(find.byKey(const ValueKey('cell-b'))).dy;
    await tester.pump(const Duration(milliseconds: 150));
    final centerY2 = tester.getTopLeft(find.byKey(const ValueKey('cell-b'))).dy;

    // The center cell's dy must change between two animation frames if bob is on.
    expect(centerY1, isNot(centerY2));
  });

  testWidgets('reduced motion stops the bob and uses jumpToPage', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
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
                itemBuilder: (_, item, _, _) => SizedBox(
                  key: ValueKey('cell-$item'),
                  width: 32,
                  height: 32,
                  child: Text(item),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final y1 = tester.getTopLeft(find.byKey(const ValueKey('cell-b'))).dy;
    await tester.pump(const Duration(milliseconds: 200));
    final y2 = tester.getTopLeft(find.byKey(const ValueKey('cell-b'))).dy;
    expect(y1, y2); // Bob frozen.
  });

  testWidgets('center cell scales larger than side cells', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
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
              itemBuilder: (_, item, _, targetSize) => SizedBox(
                key: ValueKey('cell-$item'),
                width: targetSize,
                height: targetSize,
                child: Center(child: Text(item)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final centerSize = tester.getSize(find.byKey(const ValueKey('cell-c')));
    final sideSize = tester.getSize(find.byKey(const ValueKey('cell-b')));
    expect(centerSize.height, greaterThan(sideSize.height));
  });
}
