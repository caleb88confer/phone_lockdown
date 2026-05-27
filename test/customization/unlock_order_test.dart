import 'package:flutter_test/flutter_test.dart';
import 'package:phone_lockdown/customization/key_catalog.dart';
import 'package:phone_lockdown/customization/lock_catalog.dart';
import 'package:phone_lockdown/customization/unlock_order.dart';

void main() {
  final keyIds = kKeyCatalog.map((s) => s.id).toSet();
  final lockIds = kLockCatalog.map((s) => s.id).toSet();
  final keyColorIds = kKeyCatalog
      .expand((s) => s.colors.map((c) => c.id))
      .toSet();
  final lockColorIds = kLockCatalog
      .expand((s) => s.colors.map((c) => c.id))
      .toSet();

  group('kUnlockOrder', () {
    test('has 27 entries', () {
      expect(kUnlockOrder, hasLength(27));
    });

    test('ids are unique', () {
      final ids = kUnlockOrder.map((i) => i.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('total hours sum to 241', () {
      final total = kUnlockOrder.fold<int>(0, (sum, i) => sum + i.hours);
      expect(total, 241);
    });

    test('every id resolves to a real catalog entry', () {
      for (final item in kUnlockOrder) {
        switch (item.type) {
          case UnlockType.key:
            expect(
              keyIds,
              contains(item.id),
              reason: '${item.id} missing from kKeyCatalog',
            );
          case UnlockType.lock:
            expect(
              lockIds,
              contains(item.id),
              reason: '${item.id} missing from kLockCatalog',
            );
          case UnlockType.keyColor:
            expect(
              item.id,
              startsWith('kc_'),
              reason: 'key colour ${item.id} must be kc_-namespaced',
            );
            expect(
              keyColorIds,
              contains(item.id.substring(3)),
              reason: '${item.id} missing from key palettes',
            );
          case UnlockType.lockColor:
            expect(
              item.id,
              startsWith('lc_'),
              reason: 'lock colour ${item.id} must be lc_-namespaced',
            );
            expect(
              lockColorIds,
              contains(item.id.substring(3)),
              reason: '${item.id} missing from lock palettes',
            );
        }
      }
    });

    test('bundled accents reference real catalog colours', () {
      for (final item in kUnlockOrder) {
        for (final accent in item.bundledAccents) {
          if (accent.startsWith('kc_')) {
            expect(keyColorIds, contains(accent.substring(3)));
          } else if (accent.startsWith('lc_')) {
            expect(lockColorIds, contains(accent.substring(3)));
          } else {
            fail('accent $accent must be kc_- or lc_-namespaced');
          }
        }
      }
    });
  });

  group('starting sets', () {
    test('no id appears in both a starting set and kUnlockOrder', () {
      final orderIds = kUnlockOrder.map((i) => i.id).toSet();
      final startingIds = {
        ...kStartingKeyIds,
        ...kStartingLockIds,
        ...kStartingKeyColors,
        ...kStartingLockColors,
      };
      expect(orderIds.intersection(startingIds), isEmpty);
    });

    test('starting keys resolve to real catalog entries', () {
      for (final id in kStartingKeyIds) {
        expect(keyIds, contains(id));
      }
    });

    test('starting locks resolve to real catalog entries', () {
      for (final id in kStartingLockIds) {
        expect(lockIds, contains(id));
      }
    });

    test('starting key colours are kc_-namespaced and exist', () {
      for (final id in kStartingKeyColors) {
        expect(id, startsWith('kc_'));
        expect(keyColorIds, contains(id.substring(3)));
      }
    });

    test('starting lock colours are lc_-namespaced and exist', () {
      for (final id in kStartingLockColors) {
        expect(id, startsWith('lc_'));
        expect(lockColorIds, contains(id.substring(3)));
      }
    });
  });
}
