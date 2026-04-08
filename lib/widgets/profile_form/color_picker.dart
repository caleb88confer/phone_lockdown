import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/bevel.dart';

class ProfileColorPicker extends StatelessWidget {
  final int selectedColorValue;
  final ValueChanged<int> onColorSelected;

  const ProfileColorPicker({
    super.key,
    required this.selectedColorValue,
    required this.onColorSelected,
  });

  static const colorOptions = [
    Color(0xFFFFB800), // Gold
    Color(0xFFB02D28), // Red
    Color(0xFF005BBE), // Blue
    Color(0xFF00897B), // Teal
    Color(0xFF7B1FA2), // Purple
    Color(0xFFE65100), // Orange
    Color(0xFF2E7D32), // Green
    Color(0xFFC2185B), // Pink
    Color(0xFF283593), // Indigo
    Color(0xFF00838F), // Cyan
    Color(0xFF4E342E), // Brown
    Color(0xFF546E7A), // Grey
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PROFILE COLOR',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colorOptions.map((color) {
            final isSelected = color.toARGB32() == selectedColorValue;
            return GestureDetector(
              onTap: () => onColorSelected(color.toARGB32()),
              child: Container(
                width: 48,
                height: 48,
                decoration: isSelected
                    ? Bevel.raised(fill: color)
                    : Bevel.ghost(fill: color, opacity: 0.0),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        size: 20,
                        color: color.computeLuminance() > 0.5
                            ? AppColors.onSurface
                            : Colors.white,
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
