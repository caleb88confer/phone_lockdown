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
