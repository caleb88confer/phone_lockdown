import 'package:flutter/material.dart';

class IconPicker extends StatelessWidget {
  final int selectedIconCodePoint;
  final ValueChanged<int> onIconSelected;

  const IconPicker({
    super.key,
    required this.selectedIconCodePoint,
    required this.onIconSelected,
  });

  static const iconOptions = [
    Icons.notifications_off,
    Icons.work,
    Icons.fitness_center,
    Icons.bedtime,
    Icons.school,
    Icons.restaurant,
    Icons.directions_walk,
    Icons.code,
    Icons.music_note,
    Icons.sports_esports,
    Icons.book,
    Icons.flight,
    Icons.beach_access,
    Icons.self_improvement,
    Icons.timer,
    Icons.visibility_off,
    Icons.do_not_disturb,
    Icons.phone_disabled,
    Icons.block,
    Icons.shield,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose Icon', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: iconOptions.map((icon) {
            final isSelected = icon.codePoint == selectedIconCodePoint;
            return GestureDetector(
              onTap: () => onIconSelected(icon.codePoint),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.blue.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Icon(icon, size: 24),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
