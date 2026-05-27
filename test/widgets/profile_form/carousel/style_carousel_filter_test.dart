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
    test('starting state: anchor pair + key_3 silhouette appended on the left', () async {
      final svc = await _freshUnlockState();
      final ids = visibleKeyStyles(svc).map((s) => s.id).toList();
      // Anchor: key_1 at 0, key_10 at 1. key_3 is the 1st key unlock (odd) so
      // it sits at the tail of the looping array — immediately left of key_1.
      expect(ids, ['key_1', 'key_10', 'key_3']);
    });

    test('a debug skip materialises the next key silhouette on the right', () async {
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
      // Only key_9 is a key — and it's the 2nd key unlock (even), so it lands
      // at position 2 (right of key_10). key_3 (1st key unlock, owned) stays
      // at the tail.
      expect(ids, ['key_1', 'key_10', 'key_9', 'key_3']);
    });

    test('with every item unlocked, every key in the catalog is visible', () async {
      final svc = await _freshUnlockState();
      await svc.addLockedTime(const Duration(hours: 300));
      await svc.drainPendingClaims();
      final ids = visibleKeyStyles(svc).map((s) => s.id).toList();
      expect(ids, hasLength(15));
      // Anchor stays at the front; everything else alternates outward.
      expect(ids.first, 'key_1');
      expect(ids[1], 'key_10');
    });
  });

  group('visibleLockStyles', () {
    test('starting state: anchor pair + small_sturdy left, small_oval right', () async {
      final svc = await _freshUnlockState();
      final ids = visibleLockStyles(svc).map((s) => s.id).toList();
      // Anchor: small_square (default) at 0, small_round at 1. Next-5 holds
      // small_sturdy (1st lock unlock, odd → tail/left) and small_oval (2nd
      // lock unlock, even → right of small_round).
      expect(ids, ['small_square', 'small_round', 'small_oval', 'small_sturdy']);
    });

    test('a debug skip materialises the next lock silhouette', () async {
      final svc = await _freshUnlockState();
      // Skip the first lock (small_sturdy).
      await svc.debugSkipActive(); // #1
      await svc.drainPendingClaims();

      final ids = visibleLockStyles(svc).map((s) => s.id).toList();
      // Owned: small_sturdy, small_square, small_round. Next-5 starts at #2
      // and covers kc_silver, key_3, lc_bronze, small_oval, key_9 — so
      // small_oval is the only new lock silhouette in window. small_oval is
      // the 2nd lock unlock (even → right). small_sturdy (1st, owned) sits
      // at the tail.
      expect(ids, ['small_square', 'small_round', 'small_oval', 'small_sturdy']);
    });
  });
}
