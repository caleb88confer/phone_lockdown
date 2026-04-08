import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class FailsafeSelector extends StatelessWidget {
  final int failsafeMinutes;
  final ValueChanged<int> onChanged;

  const FailsafeSelector({
    super.key,
    required this.failsafeMinutes,
    required this.onChanged,
  });

  static const presets = [
    (minutes: 15, label: '15 min'),
    (minutes: 30, label: '30 min'),
    (minutes: 60, label: '1 hour'),
    (minutes: 120, label: '2 hours'),
    (minutes: 240, label: '4 hours'),
    (minutes: 480, label: '8 hours'),
    (minutes: 720, label: '12 hours'),
    (minutes: 1440, label: '24 hours'),
  ];

  static String formatFailsafe(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    if (remaining == 0) return hours == 1 ? '1 hour' : '$hours hours';
    return '${hours}h ${remaining}m';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FAILSAFE AUTO-UNLOCK',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Automatically unlocks after this duration, even without scanning the code.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets.map((preset) {
            final isSelected = failsafeMinutes == preset.minutes;
            return GestureDetector(
              onTap: () => onChanged(preset.minutes),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: isSelected
                    ? AppColors.primaryContainer
                    : AppColors.surfaceContainerHigh,
                child: Text(
                  preset.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: isSelected
                        ? AppColors.onPrimaryContainer
                        : AppColors.onSurface,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text(
          'Current: ${formatFailsafe(failsafeMinutes)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
