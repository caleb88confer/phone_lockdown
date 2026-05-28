import 'package:flutter/material.dart';
import '../../services/lock_history_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/bevel.dart';

const _weekdayAbbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Seven beveled meter bars — one per day, oldest first. The tallest day is
/// rendered in full Signature Gold (the "best day" of the week); the rest sit
/// in the subtler [AppColors.primaryFixed]. No chart dependency: bars are
/// fraction-of-max plates inset into sunken slots, like rack-mounted meters.
class WeeklyBarChart extends StatelessWidget {
  final List<DayBucket> data;
  static const double _barAreaHeight = 132;

  const WeeklyBarChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final maxMs = data.fold<int>(0, (m, d) => d.ms > m ? d.ms : m);

    return SizedBox(
      height: _barAreaHeight + 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final bucket in data)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _Bar(
                  fraction: maxMs == 0 ? 0 : bucket.ms / maxMs,
                  isBest: maxMs > 0 && bucket.ms == maxMs,
                  label: _weekdayAbbr[bucket.date.weekday - 1],
                  labelStyle: text.labelSmall,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double fraction;
  final bool isBest;
  final String label;
  final TextStyle? labelStyle;

  const _Bar({
    required this.fraction,
    required this.isBest,
    required this.label,
    required this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: Bevel.sunken(fill: AppColors.surfaceContainerLowest),
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: fraction.clamp(0.0, 1.0),
              widthFactor: 1,
              child: Container(
                decoration: Bevel.raised(
                  fill: isBest
                      ? AppColors.primaryContainer
                      : AppColors.primaryFixed,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: labelStyle?.copyWith(
            color: isBest ? AppColors.primary : AppColors.outline,
            fontWeight: isBest ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
