# Key Style & Color Carousel — Design

**Date:** 2026-05-07
**Status:** Approved (awaiting implementation plan)

## Goal

Replace the flat key-style and key-color pickers in the Edit Profile dialog with a paired carousel UI nested inside the existing Set Key section. The style carousel is the focal element: a center-large, sides-smaller selector that spins horizontally, plays every visible key's animation, and adds a gentle vertical bob to the centered key. The color carousel sits underneath with the same gestural feel but uniform-size cells.

The Lock picker is untouched in this work; the carousel widget is built reusable so the Lock can adopt it later.

## User-visible behavior

### Set Key section layout (top to bottom)

1. `SET KEY` label (existing).
2. Existing sunken row: small key icon (or "no code" placeholder) + truncated unlock code + clear button + scan button.
3. Key style carousel — 5 cells visible, center is largest, sides scale down and squish.
4. Key color carousel — 3 cells visible, all the same size, smaller than the style carousel's center.

The pre-existing standalone "KEY" section in the form is removed; its functionality moves into Set Key.

### Style carousel

- Five visible cells: outer-left, inner-left, **center**, inner-right, outer-right.
- Sizes: center 64 px, inner sides 44 px, outer sides 28 px (sprite render size).
- Side cells are faded (inner ~70 % opacity, outer ~40 %) and horizontally squished (inner ~85 %, outer ~70 % horizontal scale) to suggest rotation.
- Every cell with `style.animated == true` runs its sprite-sheet animation continuously, regardless of which slot it occupies.
- The center cell additionally bobs vertically: ±4 px amplitude, 1400 ms period, sine-wave motion. Translation is rounded to whole pixels for crispness.
- The bob fades in/out as a cell transitions through center (weighted by its proximity to the center page) — no popping.
- Each cell renders the key tinted with the active color, falling back to grey if that style does not support the active color (display only — saved selection unchanged).

### Color carousel

- Cells are 44 px square, equal in size.
- Three visible at a time. The center cell has a `Bevel.raised` background to mark selection.
- Each cell renders the *currently-selected style's* sprite tinted in that swatch's color.
- The list of swatches is exactly the colors supported by the active style (`keyStyleById(_keyStyleId).colors`). When the active style changes, the swatch list reshapes.

### Gestures (both carousels)

- Horizontal drag with momentum (Flutter's default `PageController` fling physics).
- Snap to nearest cell on settle.
- Tap a side cell to slide it to center (`animateToPage`, 250 ms, `Curves.easeOutCubic`).
- Light haptic (`HapticFeedback.selectionClick()`) when the selected index changes after a settle (one tick per snap, not per page crossed).
- Reduced-motion respect (`MediaQuery.disableAnimationsOf`): bob amplitude → 0, snap animation → `Duration.zero`. Sprite-sheet animations are content and remain.

### Wrapping & bounds

- Style carousel: infinite loop. Scrolling past `key_15` shows `key_1`; scrolling past `key_1` backward shows `key_15`.
- Color carousel: bounce at ends (no loop). Only 4–5 swatches per style; looping would place identical swatches adjacent and feel strange.

### "Default to grey" semantics

The saved color (`Profile.keyColorId`) is preserved as the user's wish. It is not mutated when the user scrolls to a style that does not support the saved color.

- **Style carousel rendering:** for each visible style, render in the saved color if supported, else in grey.
- **Color carousel contents:** the active style's `colors` list. If the saved color is not in that list, no swatch matches it; the carousel centers on `grey` (or first color if grey is also absent — defensive; no current style hits this).
- **On color tap/snap:** the saved color is overwritten with the picked color. The picked color is always one of the active style's supported colors, so it is always renderable.
- **On style scroll:** the saved style updates; the saved color is **not** modified, even if the new style does not support it. The current code's auto-replace-when-unavailable behavior is removed.

### Worked example

User on `key_8` picks `curse` (only `key_8` supports curse).

1. Style carousel renders `key_8` in curse (center). Visible side cells (other styles) render in grey because they don't support curse. Color carousel shows `[gold, silver, grey, curse]`, centered on `curse`.
2. User scrolls the style carousel until `key_4` is the new center. Saved style → `key_4`. Saved color stays `curse`. `key_4` cell renders in grey. Color carousel reshapes to `[gold, silver, bronze, grey]`, centers on `grey`.
3. User taps `bronze`. Saved color → `bronze`. Style carousel re-tints all visible cells to bronze. `curse` is gone from saved state.
4. If after step 2 the user instead scrolled back to `key_8` without picking a color, the color carousel reshapes to `[gold, silver, grey, curse]` and centers on `curse`. Saved color (still `curse`) is honored.

## Architecture

### New files (`lib/widgets/profile_form/carousel/`)

- **`sprite_carousel.dart`** — `SpriteCarousel<T>`. Generic, reusable, knows nothing about keys/colors. Encapsulates `PageView.builder` with `viewportFraction`, infinite-loop wrap, per-page transforms (scale + opacity + horizontal squish), tap-to-snap, optional center bob, optional center bevel, haptics.
- **`key_style_carousel.dart`** — thin wrapper: passes `kKeyCatalog` and the keys-flavored config (large center, side fade + squish, bob, infinite loop, no center bevel) to `SpriteCarousel`. Item builder renders `SpriteFrame` or `AnimatedSprite` based on `style.animated`, with the grey-fallback logic baked in.
- **`key_color_carousel.dart`** — thin wrapper: passes the active style's `colors` and the colors-flavored config (uniform 44 px cells, no fade, no squish, no bob, bounce ends, center bevel) to `SpriteCarousel`. Item builder renders the active style's sprite tinted in that color (one frame, static — color cells don't need animation).

### Edits

- **`lib/widgets/profile_form/unlock_code_section.dart` → renamed `set_key_section.dart`.** Becomes the full Set Key block. New parameters for style/color selection state and change callbacks. Renders code row + style carousel + color carousel.
- **`lib/widgets/profile_form/key_picker.dart` — deleted.**
- **`lib/widgets/profile_form/profile_form_dialog.dart`** — removes the standalone Key picker container, replaces `UnlockCodeSection` with `SetKeySection`, and simplifies `_onKeyStyleChanged` to a pure `setState(() => _keyStyleId = id)` (no auto-color-replace).

### Profile model & persistence

Unchanged. `Profile.keyStyleId` and `Profile.keyColorId` already exist and are saved/loaded as before. The saved color may now be one that the saved style does not support (legitimate state) — no migration needed because all existing profiles already have valid (style, color) pairs from the auto-replace behavior; the new looser invariant only matters going forward.

### Rendering surfaces outside the form

Removing the auto-replace means a saved profile can have a (style, color) pair where the color is unsupported (e.g., `curse` on `key_4`). Every place that currently renders a key sprite from a saved profile has to use the grey-fallback resolver, otherwise the user sees a color that doesn't match what the carousel showed.

Audit:

- `lib/screens/home_screen.dart:122-123` — renders profile keys on the home screen via `keyColorById(keyStyle, p.keyColorId)`.
- `lib/widgets/profile_form/profile_form_dialog.dart:124-125` — passes the resolved color to `ScanScreen` so the in-scan key visual matches the saved selection.
- `lib/widgets/profile_form/profile_form_dialog.dart:278-279` — passes the resolved color to the small key icon in the Set Key code row.

`keyColorById` in `key_catalog.dart` is a generic lookup with a "first color" fallback — leave it alone (other code may depend on the lookup semantics). Add a new helper colocated with `renderColorIdFor`:

```dart
KeyColorOption keyColorForRender(KeyStyle style, String savedColorId) =>
    keyColorById(style, renderColorIdFor(style, savedColorId));
```

Update the three call sites above to use `keyColorForRender` instead of `keyColorById`. After this change every render path resolves through the same grey-fallback function as the carousel.

## `SpriteCarousel<T>` API

```dart
class SpriteCarousel<T> extends StatefulWidget {
  final List<T> items;
  final int selectedIndex;
  final ValueChanged<int> onSelectedChanged;

  // Layout
  final double centerSize;
  final double sideSize;
  final double edgeSize;
  final double cellGap;
  final int peekCount;          // 5 (keys) or 3 (colors)

  // Behavior
  final bool infiniteLoop;
  final bool centerBob;
  final double bobAmplitude;    // px
  final Duration bobPeriod;
  final bool sideSquish;
  final bool sideFade;
  final bool centerBevel;

  // Each visible cell receives a centerness ∈ [0, 1] (1 == fully centered)
  // so the builder can choose animated vs static rendering, etc.
  final Widget Function(BuildContext, T item, double centerness) itemBuilder;
}
```

### Configuration values

**Style carousel:** `centerSize: 64`, `sideSize: 44`, `edgeSize: 28`, `cellGap: 8`, `peekCount: 5`, `infiniteLoop: true`, `centerBob: true`, `bobAmplitude: 4`, `bobPeriod: 1400ms`, `sideSquish: true`, `sideFade: true`, `centerBevel: false`.

**Color carousel:** `centerSize: 44`, `sideSize: 44`, `edgeSize: 44`, `cellGap: 12`, `peekCount: 3`, `infiniteLoop: false`, `centerBob: false`, `sideSquish: false`, `sideFade: false`, `centerBevel: true`.

## Implementation notes

### PageView wiring

- One `PageController(viewportFraction: …)` per carousel. `viewportFraction` is computed so the center cell occupies its target slot given `centerSize`, `sideSize`, `edgeSize`, `cellGap`, and the available width. The carousel measures itself with `LayoutBuilder` and recomputes `viewportFraction` on resize.
- `infiniteLoop: true` uses `itemCount: null`. The actual item is `pageIndex % items.length`. Initial page = `items.length * 1000 + selectedIndex` (or similar large offset) so the user can fling either direction without immediately hitting the page boundary.
- `infiniteLoop: false` uses `itemCount: items.length`.

### Per-page transforms

Inside the item builder, the cell wraps its content in an `AnimatedBuilder` listening to the `PageController`. For a cell at `pageIndex`:

```
d = (controller.page - pageIndex).abs().clamp(0, 2.0)
centerness = (1.0 - d).clamp(0, 1)
```

- Scale: `lerp(centerSize, sideSize, d)` for `d ∈ [0,1]`, then `lerp(sideSize, edgeSize, d-1)` for `d ∈ [1,2]`.
- Opacity (if `sideFade`): `lerp(1.0, 0.7, d.clamp(0,1))` then `lerp(0.7, 0.4, (d-1).clamp(0,1))`.
- Horizontal squish (if `sideSquish`): `Matrix4.identity()..scale(1.0 - 0.15*d.clamp(0,1) - 0.15*(d-1).clamp(0,1), 1.0)`.

### Bob

A separate `AnimationController(duration: bobPeriod)..repeat(reverse: false)` driving phase `t ∈ [0, 2π)`. Per-frame translation:

```
dy = (-bobAmplitude * sin(t) * centerness).roundToDouble()
```

Multiplying by `centerness` makes the bob fade in/out smoothly as items pass through center. Whole-pixel rounding preserves pixel-art crispness. Disabled (amplitude → 0) when `MediaQuery.disableAnimationsOf(context)` is true.

### Selection settling

Listen to `controller` for changes; when `controller.page` is near-integer (e.g., `(page - page.round()).abs() < 0.01`) and not actively scrolling, compare `page.round() % items.length` to the prop `selectedIndex`. If different, fire `onSelectedChanged` and `HapticFeedback.selectionClick()`.

### Tap

Each cell has a `GestureDetector` (or `InkWell`) that calls `controller.animateToPage(pageIndex, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic)`. The settle handler above fires `onSelectedChanged` once the animation completes.

### Performance

Up to 5 concurrent `AnimatedSprite` widgets in the style carousel. Each is one `AnimationController` + one `IntTween` driving a `CustomPaint` with a single `drawImageRect`. This is comfortably within budget on modern Android.

## State model

State remains in `_ProfileFormDialogState`. Two pure helpers (added to `key_catalog.dart` or a new `key_resolution.dart`):

```dart
String renderColorIdFor(KeyStyle style, String savedColorId) {
  if (style.colors.any((c) => c.id == savedColorId)) return savedColorId;
  if (style.colors.any((c) => c.id == 'grey')) return 'grey';
  return style.colors.first.id;
}

int colorCenterIndex(KeyStyle style, String savedColorId) {
  final i = style.colors.indexWhere((c) => c.id == savedColorId);
  if (i != -1) return i;
  final greyI = style.colors.indexWhere((c) => c.id == 'grey');
  return greyI != -1 ? greyI : 0;
}
```

`renderColorIdFor` is used everywhere a key sprite is drawn against a possibly-mismatched color (style carousel cells, the small key icon next to the unlock code). `colorCenterIndex` tells the color carousel which item to land on when its parent reshapes.

`_onKeyStyleChanged` becomes:

```dart
void _onKeyStyleChanged(String id) => setState(() => _keyStyleId = id);
```

## Testing

### Unit tests

- `renderColorIdFor`: supported color → unchanged; unsupported on grey-bearing style → `'grey'`; unsupported on no-grey style → first color.
- `colorCenterIndex`: matching index when supported; grey index when unsupported; 0 when neither match.
- `keyColorForRender`: returns the correct `KeyColorOption` after resolution (covers integration of the two helpers above with `keyColorById`).

### Widget tests — `SpriteCarousel`

- Selected cell renders at the largest (center) size given `selectedIndex`.
- Tap on a side cell triggers `onSelectedChanged(targetIndex)` after `pumpAndSettle`.
- Drag-and-release snaps to the nearest cell and fires `onSelectedChanged` once.
- `infiniteLoop: true` allows scrolling backward from index 0 → wraps to `items.length - 1`.
- `infiniteLoop: false` clamps at endpoints (scrolling past the last cell does not wrap).
- `centerBob: true` results in a non-zero `dy` translation on the center cell mid-period; sides have `dy == 0`. (Verify by inspecting the `Transform` widget tree at a controlled animation `t`.)

### Widget tests — `KeyStyleCarousel`

- All visible animated styles have a mounted `AnimatedSprite` (count matches `peekCount` for animated styles in view).
- With `selectedColorId == 'curse'` and a non-curse style in view, that cell's `AnimatedSprite.assetPath` ends in `_grey.png`.
- Changing `selectedColorId` rebuilds visible cells with the new color (asset paths update).

### Widget tests — `KeyColorCarousel`

- `items` matches `keyStyleById(selectedStyleId).colors`.
- Changing `selectedStyleId` from `key_4` to `key_8` reshapes the swatch list.
- With `selectedStyleId: 'key_4'` and `selectedColorId: 'curse'`, the centered swatch is `'grey'` and `onColorChanged` is **not** called. Calling sequence: build only, no implicit selection mutation.

### Integration test — `profile_form_dialog`

- Set Key container contains: code row + style carousel + color carousel; standalone Key section is absent.
- Saving a profile after picking style/color persists the values via `ProfileManager` (extend existing form integration test if present).
- Saving a profile with a (style, color) pair where the style does not support the color persists both values verbatim (no auto-replace).

### Widget test — home screen rendering with looser invariant

- A profile with `keyStyleId: 'key_4'` and `keyColorId: 'curse'` renders on the home screen using the grey sprite asset (verifies the `keyColorForRender` migration on the home screen call site).

### On-device pass

- Build & install on connected Android device per `CLAUDE.md` post-change workflow.
- Verify: bob reads as intended at 4 px; 5-cell peek not cramped on small screens; swipe momentum and snap feel right; haptics fire once per snap; reduced-motion setting kills the bob and snap animation; saved-color persistence across style scroll matches the worked example above.

## Out of scope

- Lock picker redesign (Q2 = C, follow-up).
- New key styles, colors, or sprite assets.
- Any change to `Profile` serialization or the `ProfileManager` API.
- Animations on the small key icon next to the unlock code (stays as it is — single-frame `KeyDisplay`).
- Performance optimization beyond confirming "up to 5 concurrent `AnimatedSprite`s is fine."
