import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_lockdown/services/unlock_state_service.dart';
import 'package:phone_lockdown/widgets/profile_form/carousel/key_style_carousel.dart';
import 'package:phone_lockdown/widgets/sprite_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Returns a UnlockStateService with every item owned, so the carousel filter
/// shows the full catalog. Tests that exercise carousel rendering details
/// (animation, asset paths) don't care about the chunk-7 filter — that has
/// its own dedicated coverage in style_carousel_filter_test.dart.
Future<UnlockStateService> _fullyUnlockedState() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final svc = UnlockStateService(prefs: prefs);
  await svc.init();
  await svc.addLockedTime(const Duration(hours: 300));
  await svc.drainPendingClaims();
  return svc;
}

Widget _harness(
  UnlockStateService svc, {
  required String styleId,
  required String colorId,
  ValueChanged<String>? onStyleChanged,
}) {
  return ChangeNotifierProvider<UnlockStateService>.value(
    value: svc,
    child: MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          height: 100,
          child: KeyStyleCarousel(
            selectedStyleId: styleId,
            selectedColorId: colorId,
            onStyleChanged: onStyleChanged ?? (_) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders an AnimatedSprite for every visible animated style', (tester) async {
    final svc = await _fullyUnlockedState();
    await tester.pumpWidget(_harness(svc, styleId: 'key_4', colorId: 'gold'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(AnimatedSprite), findsWidgets);
  });

  testWidgets('when saved color is unsupported, the rendered asset path uses grey', (tester) async {
    String? lastTriggeredId;
    final svc = await _fullyUnlockedState();
    await tester.pumpWidget(
      _harness(
        svc,
        styleId: 'key_4',
        colorId: 'curse',
        onStyleChanged: (id) => lastTriggeredId = id,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final sprite =
        tester.widget<AnimatedSprite>(find.byType(AnimatedSprite).first);
    expect(sprite.assetPath, endsWith('_grey.png'));
    expect(lastTriggeredId, isNull);
  });
}
