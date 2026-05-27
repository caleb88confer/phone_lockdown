import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../customization/key_catalog.dart';
import '../../../services/unlock_state_service.dart';
import '../../key_display.dart';
import '../../locked_sprite_overlay.dart';
import 'sprite_carousel.dart';

/// Filter applied to [kKeyCatalog] before handing it to the carousel:
/// every owned key plus any locked key that appears in the global next-5
/// unlock window. Catalog order is preserved.
List<KeyStyle> visibleKeyStyles(UnlockStateService unlockState) {
  final windowIds = unlockState.nextLockedItems(5).map((i) => i.id).toSet();
  return kKeyCatalog
      .where((s) => unlockState.isOwned(s.id) || windowIds.contains(s.id))
      .toList(growable: false);
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
        final renderColorId = renderColorIdFor(style, selectedColorId);
        final sprite = KeyDisplay(
          key: ValueKey('keycar-${style.id}-$renderColorId-$locked'),
          style: style,
          color: keyColorById(style, renderColorId),
          size: targetSize,
          staticFrame: locked ? 0 : null,
        );
        if (!locked) return sprite;
        return LockedSpriteOverlay(child: sprite);
      },
    );
  }
}
