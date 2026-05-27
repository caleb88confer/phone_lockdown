import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../customization/lock_catalog.dart';
import '../../../services/unlock_state_service.dart';
import '../../lock_picker_sprite.dart';
import '../../locked_sprite_overlay.dart';
import 'sprite_carousel.dart';

/// Filter applied to [kLockCatalog] before handing it to the carousel:
/// every owned lock plus any locked lock that appears in the global next-5
/// unlock window. Catalog order is preserved.
List<LockStyle> visibleLockStyles(UnlockStateService unlockState) {
  final windowIds = unlockState.nextLockedItems(5).map((i) => i.id).toSet();
  return kLockCatalog
      .where((s) => unlockState.isOwned(s.id) || windowIds.contains(s.id))
      .toList(growable: false);
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
      centerSize: 85,
      sideSize: 50,
      edgeSize: 28,
      cellGap: 8,
      peekCount: 5,
      sideOutwardOffset: 12,
      infiniteLoop: true,
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
