import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_lockdown/customization/unlock_order.dart';
import 'package:phone_lockdown/screens/unlock_reveal_screen.dart';
import 'package:phone_lockdown/services/unlock_state_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<UnlockStateService> _stateWithClaims(int n) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final svc = UnlockStateService(prefs: prefs);
  await svc.init();
  for (var i = 0; i < n; i++) {
    await svc.debugSkipActive();
  }
  return svc;
}

Widget _harness(UnlockStateService svc) {
  return ChangeNotifierProvider<UnlockStateService>.value(
    value: svc,
    child: const MaterialApp(home: UnlockRevealScreen()),
  );
}

/// The reveal cards spin infinite-loop animations (BobbingSprite,
/// LockPickerSprite playing), so pumpAndSettle never returns. Use bounded
/// pumps to wait for finite navigation transitions instead.
Future<void> _settlePage(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('header shows the pending count', (tester) async {
    final svc = await _stateWithClaims(3);
    await tester.pumpWidget(_harness(svc));
    expect(find.text('YOU HAVE UNLOCKED'), findsOneWidget);
    expect(find.text('3 ITEMS'), findsOneWidget);
  });

  testWidgets('singular "1 ITEM" when only one claim is pending', (tester) async {
    final svc = await _stateWithClaims(1);
    await tester.pumpWidget(_harness(svc));
    expect(find.text('1 ITEM'), findsOneWidget);
  });

  testWidgets('CLAIM ALL is hidden on non-final pages, visible on the last', (tester) async {
    final svc = await _stateWithClaims(3);
    await tester.pumpWidget(_harness(svc));

    final firstOpacity = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.text('CLAIM ALL'),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(firstOpacity.opacity, 0.0);

    await tester.drag(find.byType(PageView), const Offset(-1000, 0));
    await _settlePage(tester);
    await tester.drag(find.byType(PageView), const Offset(-1000, 0));
    await _settlePage(tester);
    // Let AnimatedOpacity's 200ms tween finish.
    await tester.pump(const Duration(milliseconds: 300));

    final lastOpacity = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.text('CLAIM ALL'),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(lastOpacity.opacity, 1.0);
  });

  testWidgets('CLAIM ALL drains the queue and pops back', (tester) async {
    final svc = await _stateWithClaims(2);
    await tester.pumpWidget(
      ChangeNotifierProvider<UnlockStateService>.value(
        value: svc,
        child: MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(ctx).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const UnlockRevealScreen(),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await _settlePage(tester);

    // Swipe to the last (second) card.
    await tester.drag(find.byType(PageView), const Offset(-1000, 0));
    await _settlePage(tester);

    final claimedIds = svc.pendingClaimIds.toList();
    expect(claimedIds, hasLength(2));

    await tester.tap(find.text('CLAIM ALL'));
    await _settlePage(tester);

    expect(svc.pendingClaimIds, isEmpty);
    for (final id in claimedIds) {
      expect(svc.isOwned(id), isTrue);
    }
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('system back also drains the queue and pops', (tester) async {
    final svc = await _stateWithClaims(2);
    await tester.pumpWidget(
      ChangeNotifierProvider<UnlockStateService>.value(
        value: svc,
        child: MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(ctx).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const UnlockRevealScreen(),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await _settlePage(tester);
    expect(svc.pendingClaimIds, hasLength(2));

    final navState = tester.state<NavigatorState>(find.byType(Navigator));
    await navState.maybePop();
    await _settlePage(tester);

    expect(svc.pendingClaimIds, isEmpty);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('renders one PageView page per pending claim', (tester) async {
    final svc = await _stateWithClaims(3);
    await tester.pumpWidget(_harness(svc));
    final pageView = tester.widget<PageView>(find.byType(PageView));
    final delegate = pageView.childrenDelegate as SliverChildBuilderDelegate;
    expect(delegate.estimatedChildCount, 3);
  });

  testWidgets('card label is type-specific', (tester) async {
    final svc = await _stateWithClaims(3);
    expect(svc.pendingClaimIds, [
      kUnlockOrder[0].id, // small_sturdy (lock)
      kUnlockOrder[1].id, // kc_silver (key color)
      kUnlockOrder[2].id, // key_3 (key)
    ]);

    await tester.pumpWidget(_harness(svc));
    expect(find.text('Small Sturdy'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-1000, 0));
    await _settlePage(tester);
    expect(find.text('Silver keys'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-1000, 0));
    await _settlePage(tester);
    expect(find.text('Key 3'), findsOneWidget);
  });
}
