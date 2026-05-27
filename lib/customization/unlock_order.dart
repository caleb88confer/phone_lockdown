/// Single source of truth for the unlockables pilot.
///
/// Encodes the 27-item order, per-item lockdown-hour durations, and the free
/// starting loadout. Every other chunk of the unlockables system reads from
/// this file. See `unlockable_architecture.md` §4 (chunk 2) and
/// `unlockables_brainstorm.md` §3, §6, §7, §8.
library;

enum UnlockType { key, lock, keyColor, lockColor }

class UnlockItem {
  /// Stable id used for persistence and queries.
  ///
  /// Keys and locks reuse their catalog id (e.g. `'key_3'`, `'small_oval'`).
  /// Colours are namespaced — `'kc_<name>'` for key colours and `'lc_<name>'`
  /// for lock colours — because `'gold'` exists in both palettes and unlock
  /// ids share a single owned-items set.
  final String id;
  final UnlockType type;

  /// Locked-phone hours required to unlock this item once it is active.
  final int hours;

  /// Accent colour ids (same `kc_*`/`lc_*` namespacing) that go global the
  /// moment this item unlocks. Consumed by chunk 9; usually empty.
  final List<String> bundledAccents;

  const UnlockItem({
    required this.id,
    required this.type,
    required this.hours,
    this.bundledAccents = const [],
  });
}

/// The 27 unlocks in order. Phase split mirrors brainstorm §6.
const List<UnlockItem> kUnlockOrder = <UnlockItem>[
  // Early phase — quick wins (basic locks + static keys + base colours).
  UnlockItem(id: 'small_sturdy', type: UnlockType.lock, hours: 2),
  UnlockItem(id: 'kc_silver', type: UnlockType.keyColor, hours: 2),
  UnlockItem(id: 'key_3', type: UnlockType.key, hours: 3),
  UnlockItem(id: 'lc_bronze', type: UnlockType.lockColor, hours: 3),
  UnlockItem(id: 'small_oval', type: UnlockType.lock, hours: 3),
  UnlockItem(id: 'key_9', type: UnlockType.key, hours: 4),
  UnlockItem(id: 'kc_gold', type: UnlockType.keyColor, hours: 4),
  UnlockItem(id: 'shield_like', type: UnlockType.lock, hours: 4),
  UnlockItem(id: 'key_14', type: UnlockType.key, hours: 5),
  UnlockItem(id: 'lc_gold', type: UnlockType.lockColor, hours: 5),
  UnlockItem(id: 'old', type: UnlockType.lock, hours: 5),
  // Late phase — animated keys, extra-colour locks, finale.
  UnlockItem(id: 'key_4', type: UnlockType.key, hours: 5),
  UnlockItem(
    id: 'triangle',
    type: UnlockType.lock,
    hours: 6,
    bundledAccents: ['lc_beige'],
  ),
  UnlockItem(id: 'key_2', type: UnlockType.key, hours: 7),
  UnlockItem(
    id: 'sturdy',
    type: UnlockType.lock,
    hours: 8,
    bundledAccents: ['lc_red'],
  ),
  UnlockItem(id: 'key_6', type: UnlockType.key, hours: 9),
  UnlockItem(id: 'robust', type: UnlockType.lock, hours: 10),
  UnlockItem(id: 'key_11', type: UnlockType.key, hours: 10),
  UnlockItem(id: 'round', type: UnlockType.lock, hours: 11),
  UnlockItem(id: 'key_5', type: UnlockType.key, hours: 12),
  UnlockItem(id: 'hefty', type: UnlockType.lock, hours: 13),
  UnlockItem(id: 'key_12', type: UnlockType.key, hours: 14),
  UnlockItem(id: 'key_13', type: UnlockType.key, hours: 15),
  UnlockItem(id: 'key_7', type: UnlockType.key, hours: 16),
  UnlockItem(id: 'key_15', type: UnlockType.key, hours: 18),
  UnlockItem(
    id: 'extending',
    type: UnlockType.lock,
    hours: 22,
    bundledAccents: ['lc_copper', 'lc_mossy'],
  ),
  UnlockItem(
    id: 'key_8',
    type: UnlockType.key,
    hours: 25,
    bundledAccents: ['kc_curse'],
  ),
];

/// Free at first launch — see brainstorm §3. Same `kc_*`/`lc_*` namespacing
/// as `kUnlockOrder` so all four sets can be unioned into `ownedItemIds`.
const Set<String> kStartingKeyIds = {'key_1', 'key_10'};
const Set<String> kStartingLockIds = {'small_square', 'small_round'};
const Set<String> kStartingKeyColors = {'kc_grey', 'kc_bronze'};
const Set<String> kStartingLockColors = {'lc_grey', 'lc_black'};
