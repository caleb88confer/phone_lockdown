import 'package:flutter/material.dart';
import 'carousel/lock_style_carousel.dart';
import 'lock_color_row.dart';

class SetLockSection extends StatelessWidget {
  final String selectedStyleId;
  final String selectedColorId;
  final ValueChanged<String> onStyleChanged;
  final ValueChanged<String> onColorChanged;

  const SetLockSection({
    super.key,
    required this.selectedStyleId,
    required this.selectedColorId,
    required this.onStyleChanged,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SET LOCK',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        LockStyleCarousel(
          selectedStyleId: selectedStyleId,
          selectedColorId: selectedColorId,
          onStyleChanged: onStyleChanged,
        ),
        const SizedBox(height: 12),
        LockColorRow(
          selectedStyleId: selectedStyleId,
          selectedColorId: selectedColorId,
          onColorChanged: onColorChanged,
        ),
      ],
    );
  }
}
