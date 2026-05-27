# Unlockable Items — Brainstorm

> **Status:** Working doc. We hash everything out here *before* building the
> real unlock system. Nothing in this file is wired into the app yet — the only
> code that exists is the stub `UnlockedItemsService` (returns dummy `4 / 40`).

---

## 1. Goal

Add a gamified "unlockables" layer: users start with a small loadout of keys,
locks, and colors, and earn the rest over time to keep them engaged with the
core habit (locking the phone down). This is **for fun / motivation**, not
security — see the app purpose memory.

---

## 2. The full catalog (source: `lib/customization/`)

- **Keys:** 15 total — `key_1` … `key_15`.
- **Locks:** 12 total — Small Sturdy, Small Round, Small Oval, Small Square,
  Shield, Sturdy, Robust, Round, Triangle, Old, Hefty, Extending.
- **Key colors (basic):** grey, bronze, silver, gold.
- **Lock colors (basic):** grey, black, bronze, gold.
- **Accent colors (per-item extras):** red, beige, copper, mossy (locks) and
  curse (Key 8 only).

---

## 3. Starting loadout (free, never locked)

| Category | Free at start |
|---|---|
| Keys | **Key 1, Key 10** |
| Locks | **Small Square, Small Round** |
| Key colors | **grey, bronze** |
| Lock colors | **grey, black** |

---

## 4. What's unlockable — **27 items**

| Group | Count | Items |
|---|---|---|
| Keys | 13 | all except 1 & 10 |
| Locks | 10 | all except Small Square & Small Round |
| Key colors | 2 | silver, gold |
| Lock colors | 2 | bronze, gold |

Colors are **global toggles** (unlock once → applies to every key/lock).

Accent colors are **bundled, not counted** — they ride along with the item that
uses them (see §6).

---

## 5. Ordering rules (agreed)

1. **Finale:** Extending (lock) and Key 8 are the last two unlocks.
2. **Animated keys unlock later than static keys.** (Static = `animated:false`:
   keys 3, 9, 14. Everything else animates.)
3. **Extra-color locks unlock later than basic-only locks.**
4. **Extra-color locks come *after* both unlockable lock base colors**
   (Lock Bronze + Lock Gold), so the accents feel like a bonus on a lock that
   already has its full base palette.
5. **Colors front-loaded** so later unlocks can immediately use the full palette.

This produces two phases: an **early phase** of quick, simple wins (basic-only
locks + static keys + all 4 colors), then a **late phase** of richer items
(animated keys + extra-color locks) building to the finale.

---

## 6. The order — 27 steps

> "f" = animation frame count (rough proxy for how elaborate a key's animation is).

### Early phase — quick wins (colors + static keys + basic-only locks)

| # | Item | Type | Note |
|---|---|---|---|
| 1 | Small Sturdy | Lock | basic colors only |
| 2 | Key Silver | Color | key base color |
| 3 | Key 3 | Key | static |
| 4 | Lock Bronze | Color | lock base color |
| 5 | Small Oval | Lock | basic colors only |
| 6 | Key 9 | Key | static |
| 7 | Key Gold | Color | key base color |
| 8 | Shield | Lock | basic colors only |
| 9 | Key 14 | Key | static |
| 10 | Lock Gold | Color | **all base lock colors now unlocked** |
| 11 | Old | Lock | basic colors only |

### Late phase — richer items + finale

| # | Item | Type | Note |
|---|---|---|---|
| 12 | Key 4 | Key | animated (5f) |
| 13 | Triangle | Lock | + bonus **beige** (16f) |
| 14 | Key 2 | Key | animated (12f) |
| 15 | Sturdy | Lock | + bonus **red** (17f) |
| 16 | Key 6 | Key | animated (12f) |
| 17 | Robust | Lock | + bonus **red** (17f) |
| 18 | Key 11 | Key | animated (12f) |
| 19 | Round | Lock | + bonus **beige** (17f) |
| 20 | Key 5 | Key | animated (18f) |
| 21 | Hefty | Lock | + bonus **red** (18f) |
| 22 | Key 12 | Key | animated (21f) |
| 23 | Key 13 | Key | animated (25f) |
| 24 | Key 7 | Key | animated (28f) |
| 25 | Key 15 | Key | animated (48f) |
| 26 | **Extending** | Lock | **FINALE** + bonus **copper, mossy** (31f) |
| 27 | **Key 8** | Key | **FINALE** + bonus **curse** (27f) |

**Check:** every extra-color lock (#13, 15, 17, 19, 21, 26) lands after Lock
Bronze (#4) and Lock Gold (#10). ✅ Static keys (3, 9, 14) all precede the first
animated key (#12). ✅ Counts: 4 colors + 3 static keys + 4 basic locks + 10
animated keys + 6 extra-color locks = 27. ✅

---

## 7. Accent-color bundling

Accents are **not** separate unlocks; they unlock with their item.

| Accent | Unlocks with |
|---|---|
| curse | Key 8 (#27) |
| copper, mossy | Extending (#26) |
| red | first red-capable lock unlocked → Sturdy (#15) |
| beige | first beige-capable lock unlocked → Triangle (#13) |

**Decision needed:** is `red` global once any red lock is unlocked (so Robust
and Hefty just reuse it), or per-lock? Doc currently assumes **global-on-first**.
Same question for `beige`.

---

## 8. Timer & progression mechanics

**Per-item timers (decided).**
- Each unlockable carries its own duration (in locked-phone hours).
- Only **one timer is active at a time** — the next item in line per the §6 order.
- When the active item's timer hits its duration, the item enters **"pending
  claim"** state and the next item's timer starts immediately, even if the phone
  is still locked. Long lockdowns are never wasted; multiple items can stack up
  in pending-claim during a single session.
- Forced sequence (no pick-any): order is fixed, you always work on the next
  one. Adding/reordering items just changes which one is "next" — totals never
  need rebalancing.

**Duration curve (decided: scales up).**
- Target: a user locking 8h/day clears all 27 in ~30 days. Total ≈ 240h locked.
- Early phase items are quick wins (2-5h each); late phase ramps; finale items
  are the heaviest commitment.
- Starting proposal — tune to taste:

| # | Item | Hours | Cumulative |
|---|---|---|---|
| 1 | Small Sturdy | 2 | 2 |
| 2 | Key Silver | 2 | 4 |
| 3 | Key 3 | 3 | 7 |
| 4 | Lock Bronze | 3 | 10 |
| 5 | Small Oval | 3 | 13 |
| 6 | Key 9 | 4 | 17 |
| 7 | Key Gold | 4 | 21 |
| 8 | Shield | 4 | 25 |
| 9 | Key 14 | 5 | 30 |
| 10 | Lock Gold | 5 | 35 |
| 11 | Old | 5 | 40 |
| 12 | Key 4 | 5 | 45 |
| 13 | Triangle | 6 | 51 |
| 14 | Key 2 | 7 | 58 |
| 15 | Sturdy | 8 | 66 |
| 16 | Key 6 | 9 | 75 |
| 17 | Robust | 10 | 85 |
| 18 | Key 11 | 10 | 95 |
| 19 | Round | 11 | 106 |
| 20 | Key 5 | 12 | 118 |
| 21 | Hefty | 13 | 131 |
| 22 | Key 12 | 14 | 145 |
| 23 | Key 13 | 15 | 160 |
| 24 | Key 7 | 16 | 176 |
| 25 | Key 15 | 18 | 194 |
| 26 | **Extending** | 22 | 216 |
| 27 | **Key 8** | 25 | 241 |

Total: **241h ≈ 30.1 days at 8h/day.** Early phase (1–11) ≈ 5 days, late phase
(12–25) ≈ 19 days, finale (26–27) ≈ 6 days.

---

## 9. Carousel UX

**Locked items in the carousel — rolling 5-silhouette window.**
- Show: all unlocked items + the **next 5** locked items as silhouettes.
- When an item unlocks, the next blocked one slides into the window. The user
  always sees a teaser of what's coming but never has to scroll past dozens of
  dead slots.
- Silhouettes show the item's outline (so the user can tell key from lock and
  roughly anticipate what's next) — colour and detail hidden.

**Locked colours in the palette picker.**
- Different problem — palette is small (4 + 4 swatches), no scroll burden.
  Just grey out the swatch with a small lock badge. No rolling window needed.

---

## 10. Unlock delivery & reveal screen

**Trigger.**
- Threshold-crossing happens silently — the item moves to **"pending claim"**
  state and the next item's timer starts.
- The user only "receives" their items when **the phone is unlocked** (lockdown
  ended). At that point we show one consolidated reveal screen.

**Reveal screen.**
- Header: **"You have unlocked X items"** (X = number pending).
- Swipeable card stack — one card per unlocked item:
  - **Keys:** sprite playing its continuous animation + bobbing.
  - **Locks:** sprite playing its continuous animation.
  - **Colours:** 3 sample items shown in the new colour (3 keys for a key
    colour, 3 locks for a lock colour) — no animation. Showing multiple items
    implicitly conveys "this applies to everything."
- After the user swipes through all cards and dismisses, items move from
  "pending claim" → owned.

---

## 11. Open questions (before we build)

1. **Accent scope** — global-on-first vs. per-lock (see §7).
2. **Palette gaps.** Some extra-color locks lack a base color: Robust has no
   bronze; Round/Triangle/Extending have no black. Fine, but worth noting that
   "full base palette" isn't literal on every lock.
3. **Silhouette style** (§9) — outline-true (recognisable shape) vs. generic
   blob (more mystery). Currently leaning outline-true since a generic blob
   would be less motivating.

---

## 12. Implementation notes (for when we build)

- Catalog defaults currently **conflict** with the pilot starting loadout and
  will need updating:
  - `kDefaultKeyStyleId = 'key_4'` / `kDefaultKeyColorId = 'gold'` — but Key 4
    and gold are *unlockable*, not starting. Default should be Key 1 (grey or
    bronze).
  - `kDefaultLockStyleId = 'small_sturdy'` / `kDefaultLockColorId = 'grey'` —
    Small Sturdy is *unlockable*. Default should be Small Square or Small Round.
- Replace the dummy `4 / 40` in `UnlockedItemsService` with real counts derived
  from a single source-of-truth list (e.g. `lib/customization/unlock_order.dart`).
- That list should encode: the ordered 27 items + per-item durations (§8) + the
  free starting set + the accent-bundling map, so UI and counts stay in sync.
- Persisted state needs: active-item index, active-item accumulated hours,
  pending-claim queue, owned set.

**Debug / testing controls (required).**
- From the lock screen, expose **dev-only** controls to:
  - Adjust the current locked-time accumulator (jump forward / backward by Nh)
    so unlock thresholds can be crossed without waiting.
  - Reset the entire unlock state (clear pending claims, clear owned set,
    return to the §3 starting loadout, reset active-item index to 1).
- Gate behind a debug flag so the controls don't ship to users.
