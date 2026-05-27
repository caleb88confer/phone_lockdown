import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../customization/unlock_order.dart';

/// Owns all unlock-progression state: which items the user owns, which are
/// awaiting reveal, how much locked-phone time has accumulated against the
/// active item, and which bundled accents have gone global.
///
/// Chunk 3 of the unlockables architecture — see `unlockable_architecture.md`
/// §2 (state model) and §4 (chunk 3). Threshold processing is intentionally
/// absent here; chunk 6 will extend [addLockedTime] to advance the active
/// item, and chunk 9 will hook bundled-accent unlocks.
class UnlockStateService extends ChangeNotifier {
  final SharedPreferences _prefs;

  int _activeItemIndex = 1;
  int _activeAccumulatedMs = 0;
  final Set<String> _ownedItemIds = <String>{};
  final List<String> _pendingClaimIds = <String>[];
  final Set<String> _ownedAccentColorIds = <String>{};
  bool _initialized = false;

  static final Set<String> _unlockOrderIds = kUnlockOrder
      .map((i) => i.id)
      .toSet();

  UnlockStateService({required SharedPreferences prefs}) : _prefs = prefs;

  /// 1-based pointer into [kUnlockOrder]. Reaches `kUnlockOrder.length + 1`
  /// once every item has unlocked.
  int get activeItemIndex => _activeItemIndex;

  /// Locked-phone time logged against the active item but not yet consumed by
  /// a threshold crossing. Carries over after an unlock (chunk 6).
  int get activeAccumulatedMs => _activeAccumulatedMs;

  Set<String> get ownedItemIds => Set.unmodifiable(_ownedItemIds);
  List<String> get pendingClaimIds => List.unmodifiable(_pendingClaimIds);
  Set<String> get ownedAccentColorIds =>
      Set.unmodifiable(_ownedAccentColorIds);

  /// The unlock currently progressing, or `null` once every item has been
  /// claimed/queued.
  UnlockItem? get activeItem {
    final i = _activeItemIndex - 1;
    if (i < 0 || i >= kUnlockOrder.length) return null;
    return kUnlockOrder[i];
  }

  bool isOwned(String id) => _ownedItemIds.contains(id);

  /// True if a colour id is available to the palette pickers — either owned
  /// outright via [kUnlockOrder] or earned as a bundled accent (chunk 9).
  /// Accepts the same `kc_*`/`lc_*` namespacing as everywhere else.
  bool isColorAvailable(String id) =>
      _ownedItemIds.contains(id) || _ownedAccentColorIds.contains(id);

  /// True only for unlock-order items not yet unlocked and not awaiting
  /// reveal. Returns false for ids outside [kUnlockOrder] and for items in
  /// the pending-claim queue (the active index has already moved past them).
  bool isLocked(String id) {
    if (_ownedItemIds.contains(id)) return false;
    if (_pendingClaimIds.contains(id)) return false;
    return _unlockOrderIds.contains(id);
  }

  /// Rolling silhouette window — up to [n] items starting at the active
  /// index. Returns an empty list once every item has unlocked.
  List<UnlockItem> nextLockedItems(int n) {
    if (n <= 0) return const [];
    final start = _activeItemIndex - 1;
    if (start >= kUnlockOrder.length) return const [];
    final end = (start + n) > kUnlockOrder.length
        ? kUnlockOrder.length
        : start + n;
    return kUnlockOrder.sublist(start, end);
  }

  int totalOwnedCount() => _ownedItemIds.length;
  int totalUnlockableCount() => kUnlockOrder.length;

  /// Count of owned items that appear in [kUnlockOrder] — i.e. unlockable
  /// items the user has earned. Excludes the starting loadout, which is
  /// owned-from-day-one. Used for the X / 27 progress display.
  int unlockableOwnedCount() =>
      _ownedItemIds.where(_unlockOrderIds.contains).length;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final hasInitialized =
        _prefs.getBool(kPrefUnlockHasInitialized) ?? false;
    if (!hasInitialized) {
      _seedStartingState();
      await _persist();
      await _prefs.setBool(kPrefUnlockHasInitialized, true);
      return;
    }

    _activeItemIndex = _prefs.getInt(kPrefUnlockActiveIndex) ?? 1;
    _activeAccumulatedMs = _prefs.getInt(kPrefUnlockAccumulatedMs) ?? 0;
    _ownedItemIds
      ..clear()
      ..addAll(_prefs.getStringList(kPrefUnlockOwned) ?? const []);
    _pendingClaimIds
      ..clear()
      ..addAll(_prefs.getStringList(kPrefUnlockPending) ?? const []);
    _ownedAccentColorIds
      ..clear()
      ..addAll(_prefs.getStringList(kPrefUnlockOwnedAccents) ?? const []);
  }

  /// Engine entry: adds locked-phone time against the active item and fires
  /// threshold crossings. A single call can queue multiple unlocks (e.g. a
  /// 30h session crossing a 3h, an 8h, and a 25h threshold queues three
  /// items in one pass).
  Future<void> addLockedTime(Duration delta) async {
    if (delta.inMilliseconds <= 0) return;
    if (activeItem == null) return;
    _activeAccumulatedMs += delta.inMilliseconds;
    _processThresholds();
    await _persist();
    notifyListeners();
  }

  void _processThresholds() {
    while (true) {
      final item = activeItem;
      if (item == null) {
        // Ran out of unlocks; the residual accumulator is meaningless now.
        _activeAccumulatedMs = 0;
        return;
      }
      final threshold = item.hours * 3600 * 1000;
      if (_activeAccumulatedMs < threshold) return;
      _activeAccumulatedMs -= threshold;
      _unlockActiveItem();
    }
  }

  /// Reveal-flow (chunk 8): moves every pending id into [ownedItemIds] and
  /// clears the queue.
  Future<void> drainPendingClaims() async {
    if (_pendingClaimIds.isEmpty) return;
    _ownedItemIds.addAll(_pendingClaimIds);
    _pendingClaimIds.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> debugReset() async {
    _seedStartingState();
    await _persist();
    await _prefs.setBool(kPrefUnlockHasInitialized, true);
    notifyListeners();
  }

  Future<void> debugSkipActive() async {
    if (activeItem == null) return;
    _unlockActiveItem();
    _activeAccumulatedMs = 0;
    await _persist();
    notifyListeners();
  }

  /// Chunk 5 wires `+1h / +5h / +24h` buttons here. Inert until chunk 6
  /// adds threshold processing — until then this just inflates the
  /// accumulator.
  Future<void> debugAddHours(int hours) async {
    await addLockedTime(Duration(hours: hours));
  }

  void _seedStartingState() {
    _activeItemIndex = 1;
    _activeAccumulatedMs = 0;
    _ownedItemIds
      ..clear()
      ..addAll(kStartingKeyIds)
      ..addAll(kStartingLockIds)
      ..addAll(kStartingKeyColors)
      ..addAll(kStartingLockColors);
    _pendingClaimIds.clear();
    _ownedAccentColorIds.clear();
  }

  /// Pushes the active item into the pending-claim queue, folds in any
  /// bundled accents (chunk 9 — global-on-first), and advances the index.
  /// Accumulator handling is the caller's responsibility — chunk 6's
  /// threshold loop subtracts `item.hours * 3_600_000`; the debug skip
  /// zeros it.
  void _unlockActiveItem() {
    final item = activeItem;
    if (item == null) return;
    _pendingClaimIds.add(item.id);
    _ownedAccentColorIds.addAll(item.bundledAccents);
    _activeItemIndex += 1;
  }

  Future<void> _persist() async {
    await _prefs.setInt(kPrefUnlockActiveIndex, _activeItemIndex);
    await _prefs.setInt(kPrefUnlockAccumulatedMs, _activeAccumulatedMs);
    await _prefs.setStringList(kPrefUnlockOwned, _ownedItemIds.toList());
    await _prefs.setStringList(kPrefUnlockPending, _pendingClaimIds);
    await _prefs.setStringList(
      kPrefUnlockOwnedAccents,
      _ownedAccentColorIds.toList(),
    );
  }
}
