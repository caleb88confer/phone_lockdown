import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../customization/lock_catalog.dart';
import '../../../customization/unlock_order.dart';
import '../../../services/unlock_state_service.dart';
import '../../lock_picker_sprite.dart';
import '../../locked_sprite_overlay.dart';
import 'sprite_carousel.dart';

/// Carousel item order for locks. Same linear left-to-right layout as
/// [visibleKeyStyles]: small_square (default) in the middle, small_round
/// immediately right; 1st/3rd/5th … lock unlocks fan out to the left,
/// 2nd/4th/6th … to the right. Every catalog lock is always present —
/// locked ones render as silhouettes.
List<LockStyle> visibleLockStyles(UnlockStateService unlockState) {
  final lockUnlocks = kUnlockOrder
      .where((u) => u.type == UnlockType.lock)
      .toList(growable: false);

  final leftSide = <LockStyle>[];
  for (var i = 0; i < lockUnlocks.length; i += 2) {
    leftSide.add(lockStyleById(lockUnlocks[i].id));
  }

  final rightSide = <LockStyle>[];
  for (var i = 1; i < lockUnlocks.length; i += 2) {
    rightSide.add(lockStyleById(lockUnlocks[i].id));
  }

  return List.unmodifiable(<LockStyle>[
    ...leftSide.reversed,
    lockStyleById(kDefaultLockStyleId),
    lockStyleById('small_round'),
    ...rightSide,
  ]);
}

class LockStyleCarousel extends StatelessWidget {
  final String selectedStyleId;
  final String selectedColorId;
  final ValueChanged<String> onStyleChanged;

  const LockStyleCarousel({
    super.key,
    required this.selectedStyleId,
    required this.selectedColorId,
    required this.onStyleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final unlockState = context.watch<UnlockStateService>();
    final visible = visibleLockStyles(unlockState);

    if (visible.isEmpty) return const SizedBox.shrink();

    final selectedIndex = visible
        .indexWhere((s) => s.id == selectedStyleId)
        .clamp(0, visible.length - 1);

    return SpriteCarousel<LockStyle>(
      items: visible,
      selectedIndex: selectedIndex,
      onSelectedChanged: (i) {
        final style = visible[i];
        if (unlockState.isLocked(style.id)) return;
        onStyleChanged(style.id);
      },
      isItemLocked: (style) => unlockState.isLocked(style.id),
      centerSize: 85,
      sideSize: 50,
      edgeSize: 28,
      cellGap: 8,
      peekCount: 5,
      sideOutwardOffset: 12,
      infiniteLoop: false,
      centerBob: true,
      bobAmplitude: 4,
      bobPeriod: const Duration(milliseconds: 1400),
      sideSquish: false,
      sideFade: true,
      centerBevel: false,
      itemBuilder: (context, style, centerness, targetSize) {
        final locked = unlockState.isLocked(style.id);
        final renderColorId = renderLockColorIdFor(style, selectedColorId);
        final sprite = LockPickerSprite(
          key: ValueKey('lockcar-${style.id}-$renderColorId-$locked'),
          style: style,
          color: lockColorById(style, renderColorId),
          size: targetSize,
          playing: !locked && style.id == selectedStyleId,
        );
        if (!locked) return sprite;
        return LockedSpriteOverlay(child: sprite);
      },
    );
  }
}
