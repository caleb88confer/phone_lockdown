import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../customization/key_catalog.dart';
import '../../../customization/unlock_order.dart';
import '../../../services/unlock_state_service.dart';
import '../../key_display.dart';
import '../../locked_sprite_overlay.dart';
import 'sprite_carousel.dart';

/// Carousel item order for keys. Linear left-to-right layout:
///
///   [u13, u11, ..., u3, u1, key_1, key_10, u2, u4, ..., u12]
///
/// `key_1` sits in the middle (default style); `key_10` is immediately to its
/// right. Then unlocks fan out alternately: 1st, 3rd, 5th ... unlocks fill
/// to the left of `key_1`; 2nd, 4th, 6th ... unlocks fill to the right of
/// `key_10`. Every catalog key is always present — locked ones render as
/// silhouettes — so the carousel never reshuffles as items unlock.
List<KeyStyle> visibleKeyStyles(UnlockStateService unlockState) {
  final keyUnlocks = kUnlockOrder
      .where((u) => u.type == UnlockType.key)
      .toList(growable: false);

  // Odd unlocks (1st, 3rd, 5th …) go on the left, reversed so u1 ends up
  // immediately left of key_1 and the older unlocks recede further out.
  final leftSide = <KeyStyle>[];
  for (var i = 0; i < keyUnlocks.length; i += 2) {
    leftSide.add(keyStyleById(keyUnlocks[i].id));
  }

  // Even unlocks (2nd, 4th, 6th …) go on the right in chronological order
  // so u2 sits immediately right of key_10.
  final rightSide = <KeyStyle>[];
  for (var i = 1; i < keyUnlocks.length; i += 2) {
    rightSide.add(keyStyleById(keyUnlocks[i].id));
  }

  return List.unmodifiable(<KeyStyle>[
    ...leftSide.reversed,
    keyStyleById(kDefaultKeyStyleId),
    keyStyleById('key_10'),
    ...rightSide,
  ]);
}

class KeyStyleCarousel extends StatelessWidget {
  final String selectedStyleId;
  final String selectedColorId;
  final ValueChanged<String> onStyleChanged;

  const KeyStyleCarousel({
    super.key,
    required this.selectedStyleId,
    required this.selectedColorId,
    required this.onStyleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final unlockState = context.watch<UnlockStateService>();
    final visible = visibleKeyStyles(unlockState);

    if (visible.isEmpty) return const SizedBox.shrink();

    final selectedIndex = visible
        .indexWhere((s) => s.id == selectedStyleId)
        .clamp(0, visible.length - 1);

    final key1 = keyStyleById('key_1');

    return SpriteCarousel<KeyStyle>(
      items: visible,
      selectedIndex: selectedIndex,
      onSelectedChanged: (i) {
        final style = visible[i];
        if (unlockState.isLocked(style.id)) return;
        onStyleChanged(style.id);
      },
      isItemLocked: (style) => unlockState.isLocked(style.id),
      centerSize: 75,
      sideSize: 44,
      edgeSize: 26,
      cellGap: 8,
      peekCount: 5,
      infiniteLoop: false,
      centerBob: true,
      bobAmplitude: 4,
      bobPeriod: const Duration(milliseconds: 1400),
      sideSquish: false,
      sideFade: true,
      centerBevel: false,
      itemBuilder: (context, style, centerness, targetSize) {
        final locked = unlockState.isLocked(style.id);
        if (locked) {
          // Every locked key reads as the same key_1 silhouette so the user
          // can't preview which key is coming next — just that *something*
          // is. Pure black instead of the muted tint used elsewhere.
          return LockedSpriteOverlay(
            solidBlack: true,
            child: KeyDisplay(
              key: ValueKey('keycar-locked-${style.id}'),
              style: key1,
              color: key1.colors.first,
              size: targetSize,
              staticFrame: 0,
            ),
          );
        }
        final renderColorId = renderColorIdFor(style, selectedColorId);
        return KeyDisplay(
          key: ValueKey('keycar-${style.id}-$renderColorId'),
          style: style,
          color: keyColorById(style, renderColorId),
          size: targetSize,
        );
      },
    );
  }
}
