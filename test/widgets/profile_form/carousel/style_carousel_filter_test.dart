import 'package:flutter_test/flutter_test.dart';
import 'package:phone_lockdown/customization/key_catalog.dart';
import 'package:phone_lockdown/customization/lock_catalog.dart';
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

// Expected linear layout: every catalog key, with key_1 + key_10 anchored in
// the middle and unlocks fanning out by chronological order — odd unlocks
// (u1, u3, u5 …) to the left in reverse, even unlocks (u2, u4, u6 …) to the
// right in order. Locked items are still in the list; they render as
// silhouettes but the bounded physics walls them off.
const _expectedKeyOrder = <String>[
  // Reversed odd key unlocks (oldest farthest out, u1 closest to key_1):
  'key_8',  // u13
  'key_7',  // u11
  'key_12', // u9
  'key_11', // u7
  'key_2',  // u5
  'key_14', // u3
  'key_3',  // u1
  // Anchor pair:
  'key_1',
  'key_10',
  // Even key unlocks in chronological order:
  'key_9',  // u2
  'key_4',  // u4
  'key_6',  // u6
  'key_5',  // u8
  'key_13', // u10
  'key_15', // u12
];

const _expectedLockOrder = <String>[
  // Reversed odd lock unlocks:
  'hefty',        // u9
  'robust',       // u7
  'triangle',     // u5
  'shield_like',  // u3
  'small_sturdy', // u1
  // Anchor pair:
  'small_square',
  'small_round',
  // Even lock unlocks chronological:
  'small_oval', // u2
  'old',        // u4
  'sturdy',     // u6
  'round',      // u8
  'extending',  // u10
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('visibleKeyStyles', () {
    test('returns every catalog key in the alternating linear layout', () async {
      final svc = await _freshUnlockState();
      final ids = visibleKeyStyles(svc).map((s) => s.id).toList();
      expect(ids, _expectedKeyOrder);
      expect(ids, hasLength(kKeyCatalog.length));
    });

    test('layout is stable as items unlock', () async {
      final svc = await _freshUnlockState();
      await svc.debugSkipActive(); // #1 small_sturdy
      await svc.debugSkipActive(); // #2 kc_silver
      await svc.debugSkipActive(); // #3 key_3
      await svc.drainPendingClaims();
      final ids = visibleKeyStyles(svc).map((s) => s.id).toList();
      // Same array regardless of progression — only the lock/unlock state on
      // each entry changes.
      expect(ids, _expectedKeyOrder);
    });
  });

  group('visibleLockStyles', () {
    test('returns every catalog lock in the alternating linear layout', () async {
      final svc = await _freshUnlockState();
      final ids = visibleLockStyles(svc).map((s) => s.id).toList();
      expect(ids, _expectedLockOrder);
      expect(ids, hasLength(kLockCatalog.length));
    });

    test('layout is stable as items unlock', () async {
      final svc = await _freshUnlockState();
      await svc.debugSkipActive(); // #1 small_sturdy
      await svc.drainPendingClaims();
      final ids = visibleLockStyles(svc).map((s) => s.id).toList();
      expect(ids, _expectedLockOrder);
    });
  });
}
