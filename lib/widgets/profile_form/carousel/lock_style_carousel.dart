import 'package:flutter/material.dart';
import '../../../customization/lock_catalog.dart';
import '../../lock_picker_sprite.dart';
import 'sprite_carousel.dart';

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
    final selectedIndex =
        kLockCatalog.indexWhere((s) => s.id == selectedStyleId).clamp(0, kLockCatalog.length - 1);

    return SpriteCarousel<LockStyle>(
      items: kLockCatalog,
      selectedIndex: selectedIndex,
      onSelectedChanged: (i) => onStyleChanged(kLockCatalog[i].id),
      centerSize: 85,
      sideSize: 50,
      edgeSize: 28,
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
        final renderColorId = renderLockColorIdFor(style, selectedColorId);
        final isSelected = style.id == selectedStyleId;
        return LockPickerSprite(
          key: ValueKey('lockcar-${style.id}-$renderColorId-${isSelected ? 'on' : 'off'}'),
          style: style,
          color: lockColorById(style, renderColorId),
          size: targetSize,
          playing: isSelected,
        );
      },
    );
  }
}
