import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../customization/key_catalog.dart';
import '../../../customization/unlock_order.dart';
import '../../../services/unlock_state_service.dart';
import '../../key_display.dart';
import '../../locked_sprite_overlay.dart';
import 'sprite_carousel.dart';

/// Carousel item order for keys. Positions anchor on the two starting keys
/// (key_1, key_10) and then grow outward in alternating order as items
/// unlock: 2nd, 4th, 6th unlocks fill in to the right of key_10; 1st, 3rd,
/// 5th unlocks fill in to the left of key_1 (i.e. the tail of the looping
/// array). Items that are neither owned nor inside the next-5 silhouette
/// window are skipped.
List<KeyStyle> visibleKeyStyles(UnlockStateService unlockState) {
  final windowIds = unlockState.nextLockedItems(5).map((i) => i.id).toSet();
  bool visible(String id) =>
      unlockState.isOwned(id) || windowIds.contains(id);

  // Anchor pair: the default style (key_1) sits at position 0, key_10 to its
  // right at position 1.
  final result = <KeyStyle>[
    keyStyleById(kDefaultKeyStyleId),
    keyStyleById('key_10'),
  ];

  final keyUnlocks = kUnlockOrder
      .where((u) => u.type == UnlockType.key)
      .toList(growable: false);

  // Right side, chronological: 2nd, 4th, 6th, ... unlocks.
  for (var i = 1; i < keyUnlocks.length; i += 2) {
    final u = keyUnlocks[i];
    if (visible(u.id)) result.add(keyStyleById(u.id));
  }

  // Left side, reverse-chronological so u1 lands at the very last position
  // (immediately left of key_1 once the carousel wraps): u1 ends up last,
  // u3 second-to-last, etc.
  final leftSide = <KeyStyle>[];
  for (var i = 0; i < keyUnlocks.length; i += 2) {
    final u = keyUnlocks[i];
    if (visible(u.id)) leftSide.add(keyStyleById(u.id));
  }
  result.addAll(leftSide.reversed);

  return List.unmodifiable(result);
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
        // Silhouettes are browsable but not selectable — keep the parent's
        // committed selection on the previous owned style.
        if (unlockState.isLocked(style.id)) return;
        onStyleChanged(style.id);
      },
      isItemLocked: (style) => unlockState.isLocked(style.id),
      centerSize: 75,
      sideSize: 44,
      edgeSize: 26,
      cellGap: 8,
      peekCount: 5,
      infiniteLoop: true,
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
          // doesn't preview which key is coming next — just that *something*
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
