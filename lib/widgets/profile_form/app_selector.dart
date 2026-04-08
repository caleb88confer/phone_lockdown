import 'package:flutter/material.dart';
import '../../screens/app_picker_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/bevel.dart';

class AppSelector extends StatelessWidget {
  final List<String> blockedAppPackages;
  final ValueChanged<List<String>> onChanged;

  const AppSelector({
    super.key,
    required this.blockedAppPackages,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BLOCKED APPS',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final selected = await Navigator.of(context).push<List<String>>(
              MaterialPageRoute(
                builder: (_) => AppPickerScreen(
                  initialSelected: blockedAppPackages,
                ),
              ),
            );
            if (selected != null) {
              onChanged(selected);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: Bevel.raised(fill: AppColors.surfaceContainerHigh),
            child: Row(
              children: [
                const Icon(Icons.apps, size: 20, color: AppColors.onSurface),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${blockedAppPackages.length} apps blocked',
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.outline),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
