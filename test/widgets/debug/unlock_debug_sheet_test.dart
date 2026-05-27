import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_lockdown/customization/unlock_order.dart';
import 'package:phone_lockdown/services/unlock_state_service.dart';
import 'package:phone_lockdown/widgets/debug/unlock_debug_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<UnlockStateService> _freshService() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final svc = UnlockStateService(prefs: prefs);
  await svc.init();
  return svc;
}

Widget _harness(UnlockStateService svc) {
  return ChangeNotifierProvider<UnlockStateService>.value(
    value: svc,
    child: const MaterialApp(home: Scaffold(body: UnlockDebugSheet())),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows the current active item and progress', (tester) async {
    final svc = await _freshService();
    await tester.pumpWidget(_harness(svc));
    expect(find.textContaining(kUnlockOrder.first.id), findsOneWidget);
    expect(find.textContaining('0.00h'), findsOneWidget);
  });

  testWidgets('+1h bumps the accumulator by one hour', (tester) async {
    final svc = await _freshService();
    await tester.pumpWidget(_harness(svc));
    await tester.tap(find.text('+1h'));
    await tester.pump();
    expect(svc.activeAccumulatedMs, 3600 * 1000);
  });

  testWidgets('+5h bumps the accumulator by five hours', (tester) async {
    final svc = await _freshService();
    await tester.pumpWidget(_harness(svc));
    await tester.tap(find.text('+5h'));
    await tester.pump();
    expect(svc.activeAccumulatedMs, 5 * 3600 * 1000);
  });

  testWidgets('+24h bumps the accumulator by twenty-four hours', (tester) async {
    final svc = await _freshService();
    await tester.pumpWidget(_harness(svc));
    await tester.tap(find.text('+24h'));
    await tester.pump();
    expect(svc.activeAccumulatedMs, 24 * 3600 * 1000);
  });

  testWidgets('SKIP ACTIVE queues the active item and advances the index', (tester) async {
    final svc = await _freshService();
    await tester.pumpWidget(_harness(svc));
    final first = svc.activeItem!.id;
    await tester.tap(find.text('SKIP ACTIVE'));
    await tester.pump();
    expect(svc.pendingClaimIds, [first]);
    expect(svc.activeItemIndex, 2);
  });

  testWidgets('RESET goes through a confirm dialog before wiping state', (tester) async {
    final svc = await _freshService();
    await svc.debugSkipActive();
    await svc.debugAddHours(3);

    await tester.pumpWidget(_harness(svc));
    await tester.tap(find.text('RESET UNLOCK STATE'));
    await tester.pumpAndSettle();

    // Cancel first — state should not change.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(svc.activeItemIndex, 2);

    // Now confirm.
    await tester.tap(find.text('RESET UNLOCK STATE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(svc.activeItemIndex, 1);
    expect(svc.activeAccumulatedMs, 0);
    expect(svc.pendingClaimIds, isEmpty);
    expect(svc.totalOwnedCount(), 8);
  });

  testWidgets('SKIP ACTIVE disables once every item has unlocked', (tester) async {
    final svc = await _freshService();
    for (var i = 0; i < kUnlockOrder.length; i++) {
      await svc.debugSkipActive();
    }
    await tester.pumpWidget(_harness(svc));
    expect(svc.activeItem, isNull);

    // Tap should be a no-op — the button is rendered with onPressed: null.
    await tester.tap(find.text('SKIP ACTIVE'));
    await tester.pump();
    expect(svc.activeItemIndex, kUnlockOrder.length + 1);
  });

  testWidgets('readout updates live as state changes', (tester) async {
    final svc = await _freshService();
    await tester.pumpWidget(_harness(svc));
    expect(find.textContaining('0.00h'), findsOneWidget);
    await tester.tap(find.text('+5h'));
    await tester.pump();
    expect(find.textContaining('5.00h'), findsOneWidget);
  });
}
