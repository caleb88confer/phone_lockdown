import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/lock_history_service.dart';
import '../services/master_key_service.dart';
import '../theme/app_colors.dart';
import '../theme/bevel.dart';
import '../utils/duration_format.dart';
import '../widgets/dashboard/dashboard_stat_card.dart';
import '../widgets/dashboard/weekly_bar_chart.dart';

/// Read-only stats dashboard reached by long-pressing TOTAL TIME LOCKED on the
/// home screen. Rebuilt to DESIGN.md — 0px radius, machined bevels, gold hero,
/// tonal surface tiers.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'DASHBOARD',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            letterSpacing: 1.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Consumer2<MasterKeyService, LockHistoryService>(
        builder: (context, masterKey, history, _) {
          final total = masterKey.totalLockdown;
          final streak = history.currentStreak;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Hero(total: total),
                const SizedBox(height: 28),
                const _SectionLabel('THIS WEEK'),
                const SizedBox(height: 10),
                _Plate(child: WeeklyBarChart(data: history.last7Days)),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: DashboardStatCard(
                        icon: Icons.local_fire_department,
                        value: '$streak ${streak == 1 ? 'day' : 'days'}',
                        label: 'Current streak',
                        hint: 'Best: ${history.longestStreak} days',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DashboardStatCard(
                        icon: Icons.lock_outline,
                        value: '${history.sessionCount}',
                        label: 'Lock sessions',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DashboardStatCard(
                        icon: Icons.schedule,
                        value: formatDurationShort(history.averageSession),
                        label: 'Avg. session',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DashboardStatCard(
                        icon: Icons.timer_outlined,
                        value: formatDurationShort(history.longestSession),
                        label: 'Longest session',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const _SectionLabel('MILESTONES'),
                const SizedBox(height: 10),
                _Milestones(
                  totalHours: total.inHours,
                  longestStreak: history.longestStreak,
                  sessionCount: history.sessionCount,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final Duration total;
  const _Hero({required this.total});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final friendly = formatDurationFriendly(total);
    // Compact solid gold plate with a raised machined bevel. The total is the
    // headline on the home screen, so here it's a de-emphasized reference strip
    // rather than a hero block. Gradient removed per DESIGN §2 (flat fills).
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      decoration: Bevel.raised(fill: AppColors.primaryContainer),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              'TOTAL TIME LOCKED',
              style: text.labelSmall?.copyWith(
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
                color: AppColors.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            friendly.big,
            style: text.headlineSmall?.copyWith(
              height: 1.0,
              fontWeight: FontWeight.w700,
              color: AppColors.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        letterSpacing: 1.5,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface.withValues(alpha: 0.6),
      ),
    );
  }
}

class _Plate extends StatelessWidget {
  final Widget child;
  const _Plate({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: Bevel.raised(fill: AppColors.surfaceContainerHigh),
      child: child,
    );
  }
}

class _Milestones extends StatelessWidget {
  final int totalHours;
  final int longestStreak;
  final int sessionCount;

  const _Milestones({
    required this.totalHours,
    required this.longestStreak,
    required this.sessionCount,
  });

  @override
  Widget build(BuildContext context) {
    final milestones = <({String label, bool earned})>[
      (label: 'First 24h', earned: totalHours >= 24),
      (label: '7-day streak', earned: longestStreak >= 7),
      (label: '50 sessions', earned: sessionCount >= 50),
      (label: '100h locked', earned: totalHours >= 100),
    ];
    return _Plate(
      child: Column(
        children: [
          for (var i = 0; i < milestones.length; i += 2)
            Padding(
              padding: EdgeInsets.only(bottom: i + 2 < milestones.length ? 10 : 0),
              child: Row(
                children: [
                  Expanded(child: _MilestoneChip(milestones[i])),
                  const SizedBox(width: 10),
                  Expanded(child: _MilestoneChip(milestones[i + 1])),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MilestoneChip extends StatelessWidget {
  final ({String label, bool earned}) milestone;
  const _MilestoneChip(this.milestone);

  @override
  Widget build(BuildContext context) {
    final earned = milestone.earned;
    final decoration = earned
        ? Bevel.raised(fill: AppColors.primaryContainer)
        : Bevel.ghost(fill: AppColors.surfaceContainerLow, opacity: 0.2);
    final color = earned
        ? AppColors.onPrimaryContainer
        : AppColors.outline.withValues(alpha: 0.7);
    return Container(
      decoration: decoration,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Icon(
            earned ? Icons.check_circle : Icons.lock_outline,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              milestone.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: earned ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
