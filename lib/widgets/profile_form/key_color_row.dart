import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../customization/key_catalog.dart';
import '../../services/unlock_state_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/bevel.dart';
import '../key_display.dart';
import '../locked_sprite_overlay.dart';

class KeyColorRow extends StatelessWidget {
  final String selectedStyleId;
  final String selectedColorId;
  final ValueChanged<String> onColorChanged;

  const KeyColorRow({
    super.key,
    required this.selectedStyleId,
    required this.selectedColorId,
    required this.onColorChanged,
  });

  void _showLockedHint(BuildContext context) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('Locked — keep using the app to unlock'),
        duration: Duration(milliseconds: 1200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unlockState = context.watch<UnlockStateService>();
    final style = keyStyleById(selectedStyleId);
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
          final unlockId = 'kc_${c.id}';
          final locked = !unlockState.isOwned(unlockId);
          final isSelected = !locked && c.id == selectedColorId;
          final swatch = KeyDisplay(
            style: style,
            color: c,
            size: cell * 0.65,
            staticFrame: 0,
          );
          children.add(
            GestureDetector(
              onTap: locked
                  ? () => _showLockedHint(context)
                  : () => onColorChanged(c.id),
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
                child: locked ? LockedSpriteOverlay(child: swatch) : swatch,
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
