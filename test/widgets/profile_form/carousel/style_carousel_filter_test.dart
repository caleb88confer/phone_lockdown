import 'package:flutter_test/flutter_test.dart';
import 'package:phone_lockdown/services/unlock_state_service.dart';
import 'package:phone_lockdown/widgets/profile_form/carousel/key_style_carousel.dart';
import 'package:phone_lockdown/widgets/profile_form/carousel/lock_style_carousel.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<UnlockStateService> _freshUnlockState() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final svc = UnlockStateService(prefs: prefs);
  await svc.init();
  return svc;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('visibleKeyStyles', () {
    test('starting state: 2 owned keys + 1 silhouette (key_3 in next-5)', () async {
      final svc = await _freshUnlockState();
      final ids = visibleKeyStyles(svc).map((s) => s.id).toList();
      // Owned: key_1, key_10. Next-5 window holds key_3 (unlock #3).
      expect(ids, ['key_1', 'key_3', 'key_10']);
    });

    test('a debug skip materialises the next key silhouette', () async {
      final svc = await _freshUnlockState();
      // Skip past the first three items: small_sturdy, kc_silver, key_3.
      // key_3 enters pending — still not owned, still not locked (it's between).
      // After drain, key_3 is owned. The next-5 window also slides forward.
      await svc.debugSkipActive(); // #1 small_sturdy
      await svc.debugSkipActive(); // #2 kc_silver
      await svc.debugSkipActive(); // #3 key_3
      await svc.drainPendingClaims();

      final ids = visibleKeyStyles(svc).map((s) => s.id).toList();
      // Owned now: key_1, key_3, key_10. Next-5 starts at #4 (lc_bronze) and
      // covers items 4–8: lc_bronze, small_oval, key_9, kc_gold, shield_like.
      // Only key_9 is a key.
      expect(ids, ['key_1', 'key_3', 'key_9', 'key_10']);
    });

    test('with every item unlocked, every key in the catalog is visible', () async {
      final svc = await _freshUnlockState();
      await svc.addLockedTime(const Duration(hours: 300));
      await svc.drainPendingClaims();
      final ids = visibleKeyStyles(svc).map((s) => s.id).toSet();
      expect(ids, hasLength(15));
    });
  });

  group('visibleLockStyles', () {
    test('starting state: 2 owned locks + silhouettes for upcoming locks in window', () async {
      final svc = await _freshUnlockState();
      final ids = visibleLockStyles(svc).map((s) => s.id).toList();
      // Owned: small_square, small_round. Next-5 holds small_sturdy (#1) and
      // small_oval (#5).
      expect(ids, ['small_sturdy', 'small_round', 'small_oval', 'small_square']);
    });

    test('a debug skip materialises the next lock silhouette', () async {
      final svc = await _freshUnlockState();
      // Skip the first lock (small_sturdy).
      await svc.debugSkipActive(); // #1
      await svc.drainPendingClaims();

      final ids = visibleLockStyles(svc).map((s) => s.id).toList();
      // Owned: small_sturdy, small_square, small_round. Next-5 starts at #2
      // and covers kc_silver, key_3, lc_bronze, small_oval, key_9 — so
      // small_oval is the only new lock silhouette in window.
      expect(ids.toSet(), {'small_sturdy', 'small_round', 'small_square', 'small_oval'});
    });
  });
}
