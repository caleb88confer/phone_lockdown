import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_lockdown/customization/key_catalog.dart';
import 'package:phone_lockdown/services/unlock_state_service.dart';
import 'package:phone_lockdown/widgets/locked_sprite_overlay.dart';
import 'package:phone_lockdown/widgets/profile_form/key_color_row.dart';
import 'package:phone_lockdown/widgets/sprite_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<UnlockStateService> _freshUnlockState() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final svc = UnlockStateService(prefs: prefs);
  await svc.init();
  return svc;
}

Widget _harness({
  required UnlockStateService unlockState,
  required String styleId,
  required String colorId,
  ValueChanged<String>? onColorChanged,
}) {
  return ChangeNotifierProvider<UnlockStateService>.value(
    value: unlockState,
    child: MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          child: KeyColorRow(
            selectedStyleId: styleId,
            selectedColorId: colorId,
            onColorChanged: onColorChanged ?? (_) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders one swatch per color of the active style', (tester) async {
    final svc = await _freshUnlockState();
    await tester.pumpWidget(
      _harness(unlockState: svc, styleId: 'key_4', colorId: 'grey'),
    );
    await tester.pumpAndSettle();

    final colorCount = keyStyleById('key_4').colors.length;
    expect(find.byType(SpriteFrame), findsNWidgets(colorCount));
  });

  testWidgets('fits 5 swatches on a single row', (tester) async {
    final svc = await _freshUnlockState();
    await tester.pumpWidget(
      _harness(unlockState: svc, styleId: 'key_4', colorId: 'grey'),
    );
    await tester.pumpAndSettle();

    final rowSize = tester.getSize(find.byType(Row));
    expect(rowSize.height, lessThanOrEqualTo(70));
  });

  testWidgets('with unsupported saved color, does not call onColorChanged on build', (tester) async {
    final svc = await _freshUnlockState();
    String? mutated;
    await tester.pumpWidget(
      _harness(
        unlockState: svc,
        styleId: 'key_4',
        colorId: 'curse',
        onColorChanged: (id) => mutated = id,
      ),
    );
    await tester.pumpAndSettle();
    expect(mutated, isNull);
  });

  testWidgets('reshapes when selectedStyleId changes from key_4 to key_8', (tester) async {
    final svc = await _freshUnlockState();
    String styleId = 'key_4';
    String colorId = 'grey';
    await tester.pumpWidget(
      ChangeNotifierProvider<UnlockStateService>.value(
        value: svc,
        child: StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    SizedBox(
                      width: 360,
                      child: KeyColorRow(
                        selectedStyleId: styleId,
                        selectedColorId: colorId,
                        onColorChanged: (id) => setState(() => colorId = id),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => setState(() => styleId = 'key_8'),
                      child: const Text('switch'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final initialColorIds =
        keyStyleById('key_4').colors.map((c) => c.id).toList();
    expect(initialColorIds, containsAll(['gold', 'silver', 'bronze', 'grey']));

    await tester.tap(find.text('switch'));
    await tester.pumpAndSettle();

    final newColorIds = keyStyleById('key_8').colors.map((c) => c.id).toList();
    expect(newColorIds, containsAll(['gold', 'silver', 'grey', 'curse']));
    expect(newColorIds.contains('bronze'), isFalse);
  });

  group('chunk 7: locked swatches', () {
    testWidgets('starting state: bronze + grey are unlocked, gold + silver are locked', (tester) async {
      final svc = await _freshUnlockState();
      await tester.pumpWidget(
        _harness(unlockState: svc, styleId: 'key_4', colorId: 'grey'),
      );
      await tester.pumpAndSettle();
      // key_4 has 4 colors (gold, silver, bronze, grey); 2 locked.
      expect(find.byType(LockedSpriteOverlay), findsNWidgets(2));
    });

    testWidgets('tap on a locked swatch does not fire onColorChanged', (tester) async {
      final svc = await _freshUnlockState();
      String? mutated;
      await tester.pumpWidget(
        _harness(
          unlockState: svc,
          styleId: 'key_4',
          colorId: 'grey',
          onColorChanged: (id) => mutated = id,
        ),
      );
      await tester.pumpAndSettle();
      // Tap the first locked swatch (silver at index 2 — both silver and gold
      // are locked at start).
      final lockedOverlay = find.byType(LockedSpriteOverlay).first;
      await tester.tap(lockedOverlay, warnIfMissed: false);
      await tester.pump();
      expect(mutated, isNull);
    });

    testWidgets('tap on an unlocked swatch fires onColorChanged', (tester) async {
      final svc = await _freshUnlockState();
      String? mutated;
      await tester.pumpWidget(
        _harness(
          unlockState: svc,
          styleId: 'key_4',
          colorId: 'grey',
          onColorChanged: (id) => mutated = id,
        ),
      );
      await tester.pumpAndSettle();
      // Catalog order is grey(U), bronze(U), silver(L), gold(L). Indices 0 + 1
      // are unlocked. Bronze is index 1.
      final detectors = find.byType(GestureDetector);
      await tester.tap(detectors.at(1));
      await tester.pump();
      expect(mutated, 'bronze');
    });

    testWidgets('unlocking via the service refreshes the row live', (tester) async {
      final svc = await _freshUnlockState();
      await tester.pumpWidget(
        _harness(unlockState: svc, styleId: 'key_4', colorId: 'grey'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LockedSpriteOverlay), findsNWidgets(2));

      // kc_silver is unlock-order item #2. Skipping past it queues it; drain
      // moves it into ownedItemIds.
      await svc.debugSkipActive(); // #1 small_sturdy
      await svc.debugSkipActive(); // #2 kc_silver
      await svc.drainPendingClaims();
      await tester.pumpAndSettle();
      // Now only kc_gold is locked.
      expect(find.byType(LockedSpriteOverlay), findsNWidgets(1));
    });

    testWidgets('chunk 9: kc_curse becomes available on key_8 after Key 8 unlock', (tester) async {
      final svc = await _freshUnlockState();
      // Pre-unlock: key_8 has 4 colors (gold, silver, grey, curse). Of those,
      // gold + silver are unlock-order, grey is starting, curse rides bundled
      // with key_8. So 2 locked (gold + silver) plus curse = 3 locked.
      await tester.pumpWidget(
        _harness(unlockState: svc, styleId: 'key_8', colorId: 'grey'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LockedSpriteOverlay), findsNWidgets(3));

      // Unlock everything — Key 8 is the last item (#27) and bundles kc_curse.
      await svc.addLockedTime(const Duration(hours: 250));
      await svc.drainPendingClaims();
      await tester.pumpAndSettle();
      expect(find.byType(LockedSpriteOverlay), findsNothing);
    });
  });
}
