import 'package:flutter_test/flutter_test.dart';
import 'package:phone_lockdown/services/unlock_state_service.dart';
import 'package:phone_lockdown/services/unlocked_items_service.dart';
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

  test('fresh install reads 0 / 27', () async {
    final unlockState = await _freshUnlockState();
    final svc = UnlockedItemsService(unlockState: unlockState);
    expect(svc.unlockedCount, 0);
    expect(svc.totalCount, 27);
  });

  test('counter ticks up as items move into ownedItemIds', () async {
    final unlockState = await _freshUnlockState();
    final svc = UnlockedItemsService(unlockState: unlockState);

    await unlockState.debugSkipActive();
    await unlockState.drainPendingClaims();
    expect(svc.unlockedCount, 1);

    await unlockState.debugSkipActive();
    await unlockState.drainPendingClaims();
    expect(svc.unlockedCount, 2);
  });

  test('reaches 27 once every unlockable item is drained', () async {
    final unlockState = await _freshUnlockState();
    final svc = UnlockedItemsService(unlockState: unlockState);
    await unlockState.addLockedTime(const Duration(hours: 300));
    await unlockState.drainPendingClaims();
    expect(svc.unlockedCount, 27);
  });

  test('notifies listeners when the underlying state changes', () async {
    final unlockState = await _freshUnlockState();
    final svc = UnlockedItemsService(unlockState: unlockState);
    var fires = 0;
    svc.addListener(() => fires++);

    await unlockState.debugSkipActive();
    await unlockState.drainPendingClaims();
    expect(fires, greaterThan(0));
  });

  test('survives restart via the underlying service', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final us1 = UnlockStateService(prefs: prefs);
    await us1.init();
    await us1.debugSkipActive();
    await us1.drainPendingClaims();

    final us2 = UnlockStateService(prefs: prefs);
    await us2.init();
    final svc = UnlockedItemsService(unlockState: us2);
    expect(svc.unlockedCount, 1);
  });
}
