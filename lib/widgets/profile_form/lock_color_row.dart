import 'package:flutter/material.dart';
import '../../customization/lock_catalog.dart';
import '../../theme/app_colors.dart';
import '../../theme/bevel.dart';
import '../lock_picker_sprite.dart';

class LockColorRow extends StatelessWidget {
  final String selectedStyleId;
  final String selectedColorId;
  final ValueChanged<String> onColorChanged;

  const LockColorRow({
    super.key,
    required this.selectedStyleId,
    required this.selectedColorId,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    final style = lockStyleById(selectedStyleId);
    final colors = style.colors;

    const maxSlots = 5;
    const spacing = 8.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cell =
            (constraints.maxWidth - spacing * (maxSlots - 1)) / maxSlots;

        final children = <Widget>[];
        for (var i = 0; i < colors.length; i++) {
          if (i > 0) children.add(const SizedBox(width: spacing));
          final c = colors[i];
          final isSelected = c.id == selectedColorId;
          children.add(
            GestureDetector(
              onTap: () => onColorChanged(c.id),
              child: Container(
                width: cell,
                height: cell,
                alignment: Alignment.center,
                decoration: isSelected
                    ? Bevel.raised(fill: AppColors.surfaceContainerHigh)
                    : Bevel.ghost(
                        fill: AppColors.surfaceContainerLow,
                        opacity: 0.4,
                      ),
                child: LockPickerSprite(
                  style: style,
                  color: c,
                  size: cell * 0.65,
                  playing: false,
                ),
              ),
            ),
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: children,
        );
      },
    );
  }
}
