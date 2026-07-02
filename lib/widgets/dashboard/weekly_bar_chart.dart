import 'package:flutter/material.dart';
import '../../services/lock_history_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/bevel.dart';

const _weekdayAbbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _msPerHour = 3600000.0;

/// Seven daily bars on a shared plot with an hours y-axis. Bars sit on a common
/// baseline over faint hour gridlines — a conventional bar chart rather than
/// seven separated meter slots. The tallest day is drawn in full Signature Gold;
/// the rest in the subtler [AppColors.primaryFixed]. No chart dependency.
class WeeklyBarChart extends StatelessWidget {
  final List<DayBucket> data;
  static const double _plotHeight = 140;

  const WeeklyBarChart({super.key, required this.data});

  /// Pick a "nice" hour step (~4 ticks) so axis labels stay round.
  static double _niceStep(double maxHours) {
    final rough = maxHours / 4;
    const steps = [0.25, 0.5, 1, 2, 3, 4, 6, 8, 12, 24];
    for (final s in steps) {
      if (rough <= s) return s.toDouble();
    }
    return 24;
  }

  static String _fmtHour(double h) {
    if (h == h.roundToDouble()) return '${h.toInt()}h';
    return '${h.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')}h';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final maxMs = data.fold<int>(0, (m, d) => d.ms > m ? d.ms : m);
    final maxHours = maxMs / _msPerHour;

    // Empty week: show a clean 0–2h axis instead of a fractional one.
    final step = maxHours <= 0 ? 1.0 : _niceStep(maxHours);
    final divs = maxHours <= 0 ? 2 : (maxHours / step).ceil();
    final axisMax = step * divs;
    final ticks = [for (var i = 0; i <= divs; i++) step * i];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hours y-axis.
        SizedBox(
          width: 30,
          height: _plotHeight,
          child: Stack(
            children: [
              for (final t in ticks)
                Positioned(
                  top: (_plotHeight * (1 - t / axisMax) - 6)
                      .clamp(0.0, _plotHeight - 12),
                  right: 6,
                  child: Text(
                    _fmtHour(t),
                    style: text.labelSmall?.copyWith(
                      color: AppColors.outline,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              SizedBox(
                height: _plotHeight,
                child: Stack(
                  children: [
                    // Hour gridlines (baseline slightly stronger).
                    for (final t in ticks)
                      Positioned(
                        top: (_plotHeight * (1 - t / axisMax))
                            .clamp(0.0, _plotHeight - 1),
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 1,
                          color: AppColors.outlineVariant
                              .withValues(alpha: t == 0 ? 0.9 : 0.4),
                        ),
                      ),
                    // Bars on a shared baseline.
                    Positioned.fill(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final bucket in data)
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 5),
                                child: FractionallySizedBox(
                                  heightFactor:
                                      (bucket.ms / _msPerHour / axisMax)
                                          .clamp(0.0, 1.0),
                                  widthFactor: 1,
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    decoration: Bevel.raised(
                                      fill: maxMs > 0 && bucket.ms == maxMs
                                          ? AppColors.primaryContainer
                                          : AppColors.primaryFixed,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Day labels.
              Row(
                children: [
                  for (final bucket in data)
                    Expanded(
                      child: Text(
                        _weekdayAbbr[bucket.date.weekday - 1],
                        textAlign: TextAlign.center,
                        style: text.labelSmall?.copyWith(
                          color: maxMs > 0 && bucket.ms == maxMs
                              ? AppColors.primary
                              : AppColors.outline,
                          fontWeight: maxMs > 0 && bucket.ms == maxMs
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
