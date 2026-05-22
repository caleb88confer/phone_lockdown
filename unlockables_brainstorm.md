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

## 8. Open questions (before we build)

1. **Unlock trigger / cost.** What actually unlocks the next item? We already
   have `MasterKeyService` (earns "master keys" from cumulative lockdown time,
   `consume()`-able). Spend master keys per unlock? Streak/time milestones?
2. **Forced sequence vs. pick-any.** Does the path force the next item in order,
   or does reaching a tier let the user choose what to claim?
3. **Accent scope** — global-on-first vs. per-lock (see §7).
4. **Palette gaps.** Some extra-color locks lack a base color: Robust has no
   bronze; Round/Triangle/Extending have no black. Fine, but worth noting that
   "full base palette" isn't literal on every lock.

---

## 9. Implementation notes (for when we build)

- Catalog defaults currently **conflict** with the pilot starting loadout and
  will need updating:
  - `kDefaultKeyStyleId = 'key_4'` / `kDefaultKeyColorId = 'gold'` — but Key 4
    and gold are *unlockable*, not starting. Default should be Key 1 (grey or
    bronze).
  - `kDefaultLockStyleId = 'small_sturdy'` / `kDefaultLockColorId = 'grey'` —
    Small Sturdy is *unlockable*. Default should be Small Square or Small Round.
- Replace the dummy `4 / 40` in `UnlockedItemsService` with real counts derived
  from a single source-of-truth list (e.g. `lib/customization/unlock_order.dart`).
- That list should encode: the ordered 27 items + the free starting set + the
  accent-bundling map, so UI and counts stay in sync.
