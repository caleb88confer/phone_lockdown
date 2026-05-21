import 'package:flutter/material.dart';
import '../../../customization/key_catalog.dart';
import '../../key_display.dart';
import 'sprite_carousel.dart';

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
    final selectedIndex = kKeyCatalog
        .indexWhere((s) => s.id == selectedStyleId)
        .clamp(0, kKeyCatalog.length - 1);

    return SpriteCarousel<KeyStyle>(
      items: kKeyCatalog,
      selectedIndex: selectedIndex,
      onSelectedChanged: (i) => onStyleChanged(kKeyCatalog[i].id),
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
