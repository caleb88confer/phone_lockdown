import 'package:flutter/foundation.dart';

import 'unlock_state_service.dart';

/// Thin adapter exposing the unlockables progress counter (X / 27) to the
/// stats UI. Wraps [UnlockStateService] so existing widget bindings in
/// [stats_info_section.dart](../widgets/stats_info_section.dart) don't need
/// to change.
class UnlockedItemsService extends ChangeNotifier {
  final UnlockStateService _unlockState;

  UnlockedItemsService({required UnlockStateService unlockState})
    : _unlockState = unlockState {
    _unlockState.addListener(_forward);
  }

  void _forward() => notifyListeners();

  @override
  void dispose() {
    _unlockState.removeListener(_forward);
    super.dispose();
  }

  int get unlockedCount => _unlockState.unlockableOwnedCount();
  int get totalCount => _unlockState.totalUnlockableCount();
}
