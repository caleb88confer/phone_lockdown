import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_lockdown/customization/lock_catalog.dart';
import 'package:phone_lockdown/services/unlock_state_service.dart';
import 'package:phone_lockdown/widgets/locked_sprite_overlay.dart';
import 'package:phone_lockdown/widgets/profile_form/lock_color_row.dart';
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
          child: LockColorRow(
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

  testWidgets('starting state: small_square shows 2 owned + 2 locked', (tester) async {
    final svc = await _freshUnlockState();
    await tester.pumpWidget(
      _harness(unlockState: svc, styleId: 'small_square', colorId: 'grey'),
    );
    await tester.pumpAndSettle();
    // small_square has 4 colors: grey, gold, bronze, black. Starting: grey + black.
    expect(find.byType(LockedSpriteOverlay), findsNWidgets(2));
  });

  group('chunk 9: bundled accents go global', () {
    testWidgets('beige is locked on Round before Triangle unlocks', (tester) async {
      final svc = await _freshUnlockState();
      await tester.pumpWidget(
        _harness(unlockState: svc, styleId: 'round', colorId: 'grey'),
      );
      await tester.pumpAndSettle();
      // round has 4 colors: grey, gold, bronze, beige. Starting: grey only
      // (lock palette starting set is grey + black; bronze, gold, beige
      // locked). So 3 locked.
      expect(find.byType(LockedSpriteOverlay), findsNWidgets(3));
    });

    testWidgets('unlocking Triangle makes beige available on Round', (tester) async {
      final svc = await _freshUnlockState();
      // Cumulative through Triangle (#13) = 51h. Crosses Triangle's threshold
      // which queues it and folds lc_beige into ownedAccentColorIds.
      await svc.addLockedTime(const Duration(hours: 51));
      expect(svc.pendingClaimIds, contains('triangle'));
      expect(svc.ownedAccentColorIds, contains('lc_beige'));

      // Also drain so the unlocked lc_gold / lc_bronze become owned base
      // colors (cleaner accounting for the "2 locked" assertion below).
      await svc.drainPendingClaims();

      await tester.pumpWidget(
        _harness(unlockState: svc, styleId: 'round', colorId: 'grey'),
      );
      await tester.pumpAndSettle();
      // Round's palette: grey, gold, bronze, beige. After this state all
      // four are available (grey starting; gold + bronze drained; beige via
      // accent), so no LockedSpriteOverlay.
      expect(find.byType(LockedSpriteOverlay), findsNothing);
    });

    testWidgets('unlocking Sturdy makes red available on Robust', (tester) async {
      final svc = await _freshUnlockState();
      // Cumulative through Sturdy (#15) = 66h.
      await svc.addLockedTime(const Duration(hours: 66));
      await svc.drainPendingClaims();
      expect(svc.ownedAccentColorIds, contains('lc_red'));

      await tester.pumpWidget(
        _harness(unlockState: svc, styleId: 'robust', colorId: 'grey'),
      );
      await tester.pumpAndSettle();
      // Robust's palette: grey, gold, black, red. Robust itself isn't
      // unlocked yet (#17, 85h cumulative) but red rides bundled with
      // Sturdy. So: grey + black starting, gold drained, red via accent —
      // all four available.
      expect(find.byType(LockedSpriteOverlay), findsNothing);
    });

    testWidgets('unlocking Sturdy makes red available on Hefty too', (tester) async {
      final svc = await _freshUnlockState();
      await svc.addLockedTime(const Duration(hours: 66));
      await svc.drainPendingClaims();

      await tester.pumpWidget(
        _harness(unlockState: svc, styleId: 'hefty', colorId: 'grey'),
      );
      await tester.pumpAndSettle();
      // Hefty's palette: grey, gold, bronze, black, red. Same accounting as
      // Robust: all five now available.
      expect(find.byType(LockedSpriteOverlay), findsNothing);
    });

    testWidgets('tap on a freshly-globalised accent fires onColorChanged', (tester) async {
      final svc = await _freshUnlockState();
      await svc.addLockedTime(const Duration(hours: 66));
      await svc.drainPendingClaims();
      String? mutated;

      await tester.pumpWidget(
        _harness(
          unlockState: svc,
          styleId: 'robust',
          colorId: 'grey',
          onColorChanged: (id) => mutated = id,
        ),
      );
      await tester.pumpAndSettle();
      // Robust's color order: grey, gold, black, red. Red is the last
      // GestureDetector.
      final detectors = find.byType(GestureDetector);
      await tester.tap(detectors.at(lockStyleById('robust').colors.length - 1));
      await tester.pump();
      expect(mutated, 'red');
    });
  });
}
