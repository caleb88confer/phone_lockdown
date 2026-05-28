import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/bevel.dart';

/// A single beveled metric plate for the dashboard's 2×2 grid: an icon, a
/// monumental value, a tracked label, and an optional gold hint line.
class DashboardStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String? hint;

  const DashboardStatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: Bevel.raised(fill: AppColors.surfaceContainerHigh),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.outline),
          const SizedBox(height: 12),
          Text(
            value,
            style: text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: text.labelSmall?.copyWith(
              letterSpacing: 1.0,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface.withValues(alpha: 0.6),
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              style: text.labelSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
