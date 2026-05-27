# Unlockable Items — Architecture

> **Status:** Build plan derived from [`unlockables_brainstorm.md`](unlockables_brainstorm.md).
> The brainstorm doc is the source of truth for *what* (catalog, order, durations,
> reveal behaviour). This doc covers *how* and the *order* in which to build it.
> Ship chunks one at a time; each chunk is small enough for a single PR.

---

## 1. Scope

**In:** the gamified unlock loop — per-item timers, threshold detection,
pending-claim queue, reveal screen, locked-item UI in the carousel and palette
picker, debug tooling.

**Out:** cloud sync of unlock state, multi-device merge, IAP/monetisation,
re-rolling claimed unlocks, skill-tree branching paths.

---

## 2. State model

One service owns all unlock state, persisted to SharedPreferences (matches the
existing `MasterKeyService` pattern at [lib/services/master_key_service.dart](lib/services/master_key_service.dart)).

```dart
class UnlockState {
  int activeItemIndex;              // 1..27 — the item currently progressing
  int activeAccumulatedMs;          // locked-phone time logged against active item
  Set<String> ownedItemIds;         // unlocked + claimed items
  List<String> pendingClaimIds;     // unlocked, not yet revealed (FIFO queue)
  Set<String> ownedAccentColorIds;  // accents that have gone global (chunk 9)
}
```

Service surface (sketch):

```dart
class UnlockStateService extends ChangeNotifier {
  bool isOwned(String id);
  bool isLocked(String id);
  List<UnlockItem> nextLockedItems(int n);   // for the rolling silhouette window
  int totalOwnedCount();                     // for the X / 27 counter
  int totalUnlockableCount();                // 27, derived from kUnlockOrder
  // Engine-facing mutators (chunk 6):
  void addLockedTime(Duration delta);
  // Reveal/claim (chunk 8):
  void drainPendingClaims();
  // Debug (chunk 5):
  void debugReset();
  void debugSkipActive();
  void debugAddHours(int hours);
}
```

---

## 3. Component layers

```
┌──────────────────────────────────────────────────────────┐
│ UI                                                       │
│  - Carousel + palette picker (filter via state queries)  │
│  - Reveal screen (consumes pendingClaimIds)              │
│  - Debug panel (chunk 5)                                 │
└──────────────────────────────────────────────────────────┘
                          ▲
                          │ queries / events
┌──────────────────────────────────────────────────────────┐
│ Progression engine (chunk 6)                             │
│  - subscribes to the same lockdown tick as MasterKey     │
│  - increments activeAccumulatedMs                        │
│  - detects threshold crossings (handles stacked claims)  │
│  - pushes to pendingClaimIds, advances activeItemIndex   │
└──────────────────────────────────────────────────────────┘
                          ▲
┌──────────────────────────────────────────────────────────┐
│ UnlockStateService + SharedPreferences (chunk 3)         │
└──────────────────────────────────────────────────────────┘
                          ▲
┌──────────────────────────────────────────────────────────┐
│ unlock_order.dart — ordered list, durations, starting    │
│ set, accent bundles (chunk 2)                            │
└──────────────────────────────────────────────────────────┘
```

---

## 4. Feature chunks (build in this order)

### Chunk 1 — Catalog default fixes

**Why first:** the current defaults reference *unlockable* items, so a fresh
install would land on locked content. This is a 4-line fix with no dependencies
and unblocks every chunk that filters by the starting set.

**Change:**
- [lib/customization/key_catalog.dart:227-228](lib/customization/key_catalog.dart#L227-L228) — `kDefaultKeyStyleId: 'key_4' → 'key_1'`, `kDefaultKeyColorId: 'gold' → 'grey'` (or `'bronze'`).
- [lib/customization/lock_catalog.dart:240-241](lib/customization/lock_catalog.dart#L240-L241) — `kDefaultLockStyleId: 'small_sturdy' → 'small_square'` (or `'small_round'`). `kDefaultLockColorId: 'grey'` stays.

**Depends on:** nothing.
**Done when:** fresh install lands on a starting-set combo.

---

### Chunk 2 — Source-of-truth `unlock_order.dart`

**Goal:** encode brainstorm §8 as Dart data so all other chunks read from one place.

**Deliverable:** new [lib/customization/unlock_order.dart](lib/customization/unlock_order.dart) containing:

```dart
enum UnlockType { key, lock, keyColor, lockColor }

class UnlockItem {
  final String id;                    // 'small_sturdy', 'kc_silver', 'lc_bronze', ...
  final UnlockType type;
  final int hours;                    // duration to unlock
  final List<String> bundledAccents;  // chunk 9; usually empty
  const UnlockItem({...});
}

const List<UnlockItem> kUnlockOrder = [ /* 27 entries from §8 */ ];
const Set<String> kStartingKeyIds      = {'key_1', 'key_10'};
const Set<String> kStartingLockIds     = {'small_square', 'small_round'};
const Set<String> kStartingKeyColors   = {'grey', 'bronze'};
const Set<String> kStartingLockColors  = {'grey', 'black'};
```

**ID convention:** keys/locks use existing catalog ids (`'key_3'`, `'small_oval'`).
Colours need a namespace because `'gold'` exists in both palettes — use
`'kc_<name>'` for key colours, `'lc_<name>'` for lock colours.

**Depends on:** nothing (pure data).
**Done when:** unit test verifies (a) 27 entries, (b) every id is present in the
catalogs, (c) total hours sum to **241**, (d) no id appears in both starting set
and `kUnlockOrder`.

---

### Chunk 3 — `UnlockStateService` + persistence

**Goal:** real state — the model in §2 backed by SharedPreferences.

**First-launch seed:**
- `ownedItemIds` = starting set (2 keys + 2 locks + 2 key colours + 2 lock colours = 8 items).
- `activeItemIndex = 1`, `activeAccumulatedMs = 0`.
- `pendingClaimIds` = [], `ownedAccentColorIds` = {}.

**Deliverable:** new `lib/services/unlock_state_service.dart`. Mirror
`MasterKeyService`'s init pattern (`Future<void> init()`, `_prefs` injection,
`notifyListeners()` on mutation). Register in [lib/main.dart](lib/main.dart) alongside the
other services.

**Depends on:** chunk 2.
**Done when:** state survives restart; helper queries return expected values for
the seeded state.

---

### Chunk 4 — Wire real counts into `UnlockedItemsService`

**Goal:** kill the dummy `4 / 40` in [lib/services/unlocked_items_service.dart](lib/services/unlocked_items_service.dart).

**Change:** `unlockedCount` → `UnlockStateService.totalOwnedCount()`,
`totalCount` → `27` (or `totalUnlockableCount()`). Service becomes a thin
adapter over `UnlockStateService` — could even be folded in entirely, but the
existing widget bindings ([lib/widgets/stats_info_section.dart](lib/widgets/stats_info_section.dart)) are easier to leave alone.

**Depends on:** chunks 2 + 3.
**Done when:** fresh install reads `8 / 27` (or whatever the starting count is —
verify), persists across restart.

---

### Chunk 5 — Debug controls

**Why now:** unblocks testing of chunks 6+. No one wants to wait real hours.

**Deliverable:** dev-only panel reachable from the lock screen. Suggest a hidden
long-press on a lock-screen element (decide at impl). Controls:

| Control | Effect |
|---|---|
| **Reset unlock state** | Reseed to chunk-3 starting state. |
| **Skip active item** | Push current item to `pendingClaimIds`, advance index, zero accumulator. |
| **+1h / +5h / +24h** | Bump `activeAccumulatedMs`; triggers threshold check (only does anything useful after chunk 6). |

**Gate:** `kDebugMode` (or a build-time flag). Don't ship to release.

**Depends on:** chunk 3. The `+Nh` buttons are present but inert until chunk 6
lands — that's fine.
**Done when:** full unlock sequence can be walked in under 5 minutes from a
debug build.

---

### Chunk 6 — Progression engine

**Goal:** lockdown time accumulates against the active item; threshold crossings
queue claims and advance the index.

**Hook point:** the tick path in [lib/services/master_key_service.dart](lib/services/master_key_service.dart) — the same
signal that drives `_progressMs`. Either:
- **(a)** Wire `UnlockStateService.addLockedTime(delta)` into the same tick, OR
- **(b)** Have `UnlockStateService` listen to the same `AppBlockerService` and
  run its own session timer.

Lean **(a)** — single source of timing truth, no risk of drift.

**Threshold loop** (runs after every `addLockedTime`):

```
while activeItemIndex <= 27 AND activeAccumulatedMs >= currentItem.hours * 3600_000:
  activeAccumulatedMs -= currentItem.hours * 3600_000
  pendingClaimIds.add(currentItem.id)
  activeItemIndex += 1
```

The `while` (not `if`) handles stacked crossings: a 30h lockdown that crosses a
3h, an 8h, and a 25h threshold queues three items in one pass.

**Deliverable:** new `lib/services/progression_engine.dart` (or methods on
`UnlockStateService` — pick at impl, leaning toward folding into the service to
keep state mutations in one place).

**Depends on:** chunks 2, 3.
**Done when:** debug `+Nh` crossings queue the right items; stacked crossings
work; restart preserves the queue.

---

### Chunk 7 — Locked-item UI (carousel + palette)

**Goal:** the UI reflects what's owned vs. locked.

**Carousel:** filter to `owned ∪ next 5 silhouettes`. Silhouette = the existing
sprite rendered as a solid dark shape (no colour, no animation) with a small
lock-badge overlay. The next-5 list comes from
`UnlockStateService.nextLockedItems(5)`.

**Palette picker:** locked swatches → greyed-out + lock badge. Tap is a no-op (or
a brief "locked" hint).

**Files:** customization carousel widget(s) under `lib/customization/` and/or
the palette picker — confirm at impl time.

**Coupling — ship 3 + 4 + 7 together (or behind a single feature flag).** Until
chunk 7 lands, chunks 3 + 4 alone would shrink the visible carousel to just the
starting set with no preview of what's next — bad UX gap.

**Depends on:** chunks 2, 3.
**Done when:** carousel shows starting items + 5 silhouettes; palette shows 4
swatches with 2 greyed; a debug-skip materialises the next silhouette.

---

### Chunk 8 — Reveal flow

**Goal:** when a lockdown ends with `pendingClaimIds` non-empty, the user gets
the reward screen before returning to the main app.

**(a) Detection** — hook the lockdown-end signal (whatever path dismisses the
lock screen / [lib/services/app_blocker_service.dart](lib/services/app_blocker_service.dart) reports
"no locks active"). If `pendingClaimIds.isNotEmpty`, navigate to the reveal
screen first.

**(b) Reveal screen** — `lib/screens/unlock_reveal_screen.dart`. Header:
`"You have unlocked X items"`. Horizontal `PageView` of cards, one per pending
item:

| Item type | Card content |
|---|---|
| Key    | sprite playing continuous animation + bobbing effect |
| Lock   | sprite playing continuous animation |
| Colour | 3 sample items (keys for `kc_*`, locks for `lc_*`) rendered in the new colour, **no animation** |

On dismissing the last card (or hitting a "Claim all" button — decide at impl;
lean swipe-through with a button on the final card), call
`UnlockStateService.drainPendingClaims()` to move every id into `ownedItemIds`.

**Depends on:** chunks 2, 3, 6.
**Done when:** debug-skipping 3 items, then ending lockdown, produces a 3-card
reveal that drains correctly on dismiss.

---

### Chunk 9 — Accent colour bundling

**Goal:** when an accent-bearing item unlocks, its accent becomes globally usable.

**Resolve first** (brainstorm §11.1): **global-on-first vs. per-lock**.
Recommendation: **global-on-first** — matches the "earned, applies broadly"
intent of base colours. Confirm before coding.

**Logic:** in the threshold loop (chunk 6), after pushing an item to
`pendingClaimIds`, look up `bundledAccents` and `ownedAccentColorIds.addAll(...)`.
Palette pickers for accent-capable items consult `ownedAccentColorIds`.

**Affected items** (from brainstorm §7):

| Accent | Source item | Also benefits |
|---|---|---|
| beige  | Triangle (#13) | Round (#19) |
| red    | Sturdy (#15)   | Robust (#17), Hefty (#21) |
| copper, mossy | Extending (#26) | — |
| curse  | Key 8 (#27) | — |

**Depends on:** chunks 2, 3, 6, 7.
**Done when:** unlocking Triangle makes beige available on Round; unlocking
Sturdy makes red available on Robust and Hefty.

---

## 5. Sequencing & coupling

- **Chunks 1, 2** can ship anytime — pure data / config.
- **Chunks 3, 4, 7 must ship together** (or behind one flag flipped together) —
  otherwise the user briefly sees an inventory shrunk to the starting set with
  no rolling-window preview.
- **Chunk 5 before chunk 6** — debug tools first so the engine is testable.
- **Chunk 6 unblocks 8 and 9.**
- **Chunk 8** is the reward moment; after it lands the loop is shippable.
  **Chunk 9** is polish.

**Suggested PR sequence:**

1. Chunk 1 (defaults)
2. Chunk 2 (`unlock_order.dart`)
3. Chunk 5a (`UnlockStateService` + reset/skip debug, no engine yet — relies on chunk 3 internals; ship together)
4. Chunks 3 + 4 + 7 in one PR behind a feature flag
5. Chunk 6 (engine; flip flag on)
6. Chunk 8 (reveal)
7. Chunk 9 (accents)

---

## 6. Open questions (carry-over from brainstorm §11)

1. **Accent scope** (chunk 9) — global-on-first vs. per-lock. *Lean global-on-first.*
2. **Silhouette style** (chunk 7) — outline-true (recognisable shape) vs. generic
   blob. *Lean outline-true.*
3. **Reveal dismissal** (chunk 8) — pure swipe-through vs. "Claim all" button on
   the final card. *Lean swipe-through with a button on the final card.*
4. **Debug entry point** (chunk 5) — hidden long-press, debug-only button,
   gesture? *Decide at impl.*

---

## 7. Risks & migration

- **Existing installs.** Users on a current build have `kDefaultKeyStyleId =
  'key_4'` etc. saved in prefs. When the unlock system goes live, those users'
  saved selections may reference items they don't "own" under the new rules.
  Decide at chunk 3: (a) grandfather their current selection into `ownedItemIds`,
  or (b) reset selection to the starting loadout and surface the rest via the
  normal unlock path. *Lean (a) for kindness, but flag for Caleb before coding.*
- **`MasterKeyService` "seeds 3 master keys on first run" debug behaviour**
  ([lib/services/master_key_service.dart:54-60](lib/services/master_key_service.dart#L54-L60))
  may interact awkwardly with unlock testing. Audit at chunk 3.
- **Time-source drift.** If chunks 6 and `MasterKeyService` independently track
  the same lockdown session, they will drift. Single source of truth (option (a)
  in chunk 6) avoids this.
