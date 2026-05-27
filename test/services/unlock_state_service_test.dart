import 'package:flutter_test/flutter_test.dart';
import 'package:phone_lockdown/customization/unlock_order.dart';
import 'package:phone_lockdown/services/unlock_state_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<UnlockStateService> _freshService([Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  final svc = UnlockStateService(prefs: prefs);
  await svc.init();
  return svc;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('first-run seed', () {
    test('seeds the 8 starting items as owned', () async {
      final svc = await _freshService();
      expect(svc.totalOwnedCount(), 8);
      expect(svc.ownedItemIds, {
        ...kStartingKeyIds,
        ...kStartingLockIds,
        ...kStartingKeyColors,
        ...kStartingLockColors,
      });
    });

    test('active item is kUnlockOrder[0] with a zero accumulator', () async {
      final svc = await _freshService();
      expect(svc.activeItemIndex, 1);
      expect(svc.activeAccumulatedMs, 0);
      expect(svc.activeItem?.id, kUnlockOrder.first.id);
    });

    test('pending queue and accent set are empty', () async {
      final svc = await _freshService();
      expect(svc.pendingClaimIds, isEmpty);
      expect(svc.ownedAccentColorIds, isEmpty);
    });

    test('totalUnlockableCount is 27', () async {
      final svc = await _freshService();
      expect(svc.totalUnlockableCount(), 27);
    });

    test('unlockableOwnedCount excludes the starting loadout', () async {
      final svc = await _freshService();
      expect(svc.unlockableOwnedCount(), 0);
    });
  });

  group('unlockableOwnedCount', () {
    test('only ticks up on items in kUnlockOrder', () async {
      final svc = await _freshService();
      await svc.debugSkipActive();
      await svc.drainPendingClaims();
      expect(svc.unlockableOwnedCount(), 1);
    });

    test('reaches 27 once every unlockable item is drained', () async {
      final svc = await _freshService();
      await svc.addLockedTime(const Duration(hours: 300));
      await svc.drainPendingClaims();
      expect(svc.unlockableOwnedCount(), 27);
      expect(svc.totalOwnedCount(), 8 + 27);
    });
  });

  group('helper queries', () {
    test('isOwned distinguishes starting items from unlockables', () async {
      final svc = await _freshService();
      expect(svc.isOwned('key_1'), isTrue);
      expect(svc.isOwned('small_square'), isTrue);
      expect(svc.isOwned('kc_grey'), isTrue);
      expect(svc.isOwned('small_sturdy'), isFalse);
      expect(svc.isOwned('key_8'), isFalse);
    });

    test('isLocked is true only for unlock-order items not yet unlocked', () async {
      final svc = await _freshService();
      expect(svc.isLocked('small_sturdy'), isTrue);
      expect(svc.isLocked('key_8'), isTrue);
      expect(svc.isLocked('key_1'), isFalse); // owned
      expect(svc.isLocked('not_in_catalog'), isFalse); // outside the universe
    });

    test('nextLockedItems returns the rolling window from activeIndex', () async {
      final svc = await _freshService();
      final window = svc.nextLockedItems(5);
      expect(window.map((i) => i.id).toList(), [
        for (var i = 0; i < 5; i++) kUnlockOrder[i].id,
      ]);
    });

    test('nextLockedItems clamps to the remaining items', () async {
      final svc = await _freshService();
      expect(svc.nextLockedItems(0), isEmpty);
      expect(svc.nextLockedItems(-3), isEmpty);
      expect(svc.nextLockedItems(100), hasLength(kUnlockOrder.length));
    });
  });

  group('debug controls', () {
    test('debugSkipActive queues the active item and advances the index', () async {
      final svc = await _freshService();
      final first = svc.activeItem!.id;
      await svc.debugSkipActive();
      expect(svc.pendingClaimIds, [first]);
      expect(svc.activeItemIndex, 2);
      expect(svc.activeAccumulatedMs, 0);
      expect(svc.isLocked(first), isFalse, reason: 'pending, not locked');
      expect(svc.isOwned(first), isFalse, reason: 'not owned until drained');
    });

    test('debugSkipActive past the last item is a no-op', () async {
      final svc = await _freshService();
      // Skip all 27.
      for (var i = 0; i < kUnlockOrder.length; i++) {
        await svc.debugSkipActive();
      }
      expect(svc.activeItem, isNull);
      expect(svc.activeItemIndex, kUnlockOrder.length + 1);
      final indexBefore = svc.activeItemIndex;
      await svc.debugSkipActive();
      expect(svc.activeItemIndex, indexBefore);
    });

    test('debugAddHours under the first threshold leaves the index alone', () async {
      final svc = await _freshService();
      // First item is Small Sturdy (2h).
      await svc.debugAddHours(1);
      expect(svc.activeAccumulatedMs, 3600 * 1000);
      expect(svc.activeItemIndex, 1);
      expect(svc.pendingClaimIds, isEmpty);
    });

    test('debugReset returns to the first-run seed', () async {
      final svc = await _freshService();
      await svc.debugSkipActive();
      await svc.debugAddHours(5);
      await svc.debugReset();
      expect(svc.activeItemIndex, 1);
      expect(svc.activeAccumulatedMs, 0);
      expect(svc.pendingClaimIds, isEmpty);
      expect(svc.totalOwnedCount(), 8);
    });
  });

  group('threshold loop (chunk 6)', () {
    test('crossing one threshold queues one unlock and carries the remainder', () async {
      final svc = await _freshService();
      // Small Sturdy is 2h. +3h crosses once with 1h remaining.
      await svc.addLockedTime(const Duration(hours: 3));
      expect(svc.activeItemIndex, 2);
      expect(svc.pendingClaimIds, [kUnlockOrder[0].id]);
      expect(svc.activeAccumulatedMs, 1 * 3600 * 1000);
      // The unlocked item is queued, not yet owned.
      expect(svc.isOwned(kUnlockOrder[0].id), isFalse);
    });

    test('stacked crossings queue multiple unlocks in one pass', () async {
      final svc = await _freshService();
      // First three items: Small Sturdy 2h, Key Silver 2h, Key 3 3h → sum 7h.
      // +8h crosses all three with 1h remaining on Lock Bronze (3h).
      await svc.addLockedTime(const Duration(hours: 8));
      expect(svc.activeItemIndex, 4);
      expect(svc.pendingClaimIds, [
        kUnlockOrder[0].id,
        kUnlockOrder[1].id,
        kUnlockOrder[2].id,
      ]);
      expect(svc.activeAccumulatedMs, 1 * 3600 * 1000);
    });

    test('crossing exactly on the threshold leaves a zero accumulator', () async {
      final svc = await _freshService();
      // Small Sturdy is exactly 2h.
      await svc.addLockedTime(const Duration(hours: 2));
      expect(svc.activeItemIndex, 2);
      expect(svc.pendingClaimIds, [kUnlockOrder[0].id]);
      expect(svc.activeAccumulatedMs, 0);
    });

    test('crossing every threshold ends with a null active item', () async {
      final svc = await _freshService();
      // Total of every duration is 241h per the brainstorm; +250h crosses all.
      await svc.addLockedTime(const Duration(hours: 250));
      expect(svc.activeItem, isNull);
      expect(svc.activeItemIndex, kUnlockOrder.length + 1);
      expect(svc.pendingClaimIds, hasLength(kUnlockOrder.length));
      expect(svc.activeAccumulatedMs, 0,
          reason: 'residual time is discarded once every item has unlocked');
    });

    test('addLockedTime is a no-op once every item has unlocked', () async {
      final svc = await _freshService();
      await svc.addLockedTime(const Duration(hours: 250));
      expect(svc.activeItem, isNull);
      await svc.addLockedTime(const Duration(hours: 5));
      expect(svc.activeAccumulatedMs, 0);
      expect(svc.pendingClaimIds, hasLength(kUnlockOrder.length));
    });

    test('crossings survive restart', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final svc1 = UnlockStateService(prefs: prefs);
      await svc1.init();
      await svc1.addLockedTime(const Duration(hours: 8));

      final svc2 = UnlockStateService(prefs: prefs);
      await svc2.init();
      expect(svc2.activeItemIndex, 4);
      expect(svc2.pendingClaimIds, [
        kUnlockOrder[0].id,
        kUnlockOrder[1].id,
        kUnlockOrder[2].id,
      ]);
      expect(svc2.activeAccumulatedMs, 1 * 3600 * 1000);
    });
  });

  group('drainPendingClaims', () {
    test('moves the queue into ownedItemIds and clears it', () async {
      final svc = await _freshService();
      await svc.debugSkipActive();
      await svc.debugSkipActive();
      final claimed = svc.pendingClaimIds.toList();
      await svc.drainPendingClaims();
      expect(svc.pendingClaimIds, isEmpty);
      for (final id in claimed) {
        expect(svc.isOwned(id), isTrue);
      }
    });

    test('is a no-op when the queue is empty', () async {
      final svc = await _freshService();
      final ownedBefore = svc.totalOwnedCount();
      await svc.drainPendingClaims();
      expect(svc.totalOwnedCount(), ownedBefore);
    });
  });

  group('persistence', () {
    test('mutated state survives a fresh service instance', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final svc1 = UnlockStateService(prefs: prefs);
      await svc1.init();
      await svc1.debugSkipActive();
      await svc1.debugSkipActive();
      // Active is now key_3 (3h); +2h stays under the threshold so we can
      // assert the accumulator round-trips intact.
      await svc1.debugAddHours(2);

      final svc2 = UnlockStateService(prefs: prefs);
      await svc2.init();
      expect(svc2.activeItemIndex, 3);
      expect(svc2.activeAccumulatedMs, 2 * 3600 * 1000);
      expect(svc2.pendingClaimIds, [
        kUnlockOrder[0].id,
        kUnlockOrder[1].id,
      ]);
      expect(svc2.totalOwnedCount(), 8);
    });

    test('does not re-seed on a second init', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final svc1 = UnlockStateService(prefs: prefs);
      await svc1.init();
      await svc1.drainPendingClaims(); // no-op, just exercising mutation paths

      // Manually mutate then reload — second init must not wipe the state.
      await svc1.debugSkipActive();
      final svc2 = UnlockStateService(prefs: prefs);
      await svc2.init();
      expect(svc2.activeItemIndex, 2);
      expect(svc2.pendingClaimIds, hasLength(1));
    });
  });
}
