import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_lockdown/customization/key_catalog.dart';
import 'package:phone_lockdown/widgets/profile_form/carousel/key_style_carousel.dart';
import 'package:phone_lockdown/widgets/sprite_sheet.dart';

void main() {
  testWidgets('renders an AnimatedSprite for every visible animated style', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
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
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // At least one AnimatedSprite mounted (center is animated).
    expect(find.byType(AnimatedSprite), findsWidgets);
  });

  testWidgets(
    'when saved color is unsupported, the rendered asset path uses grey',
    (tester) async {
      String? lastTriggeredId;
      await tester.pumpWidget(
        MaterialApp(
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
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Find any AnimatedSprite and confirm its assetPath ends with _grey.png.
      final sprite = tester.widget<AnimatedSprite>(
        find.byType(AnimatedSprite).first,
      );
      expect(sprite.assetPath, endsWith('_grey.png'));
      expect(lastTriggeredId, isNull);
    },
  );
}
