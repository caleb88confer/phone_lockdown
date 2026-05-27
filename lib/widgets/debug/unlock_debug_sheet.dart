import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../customization/unlock_order.dart';
import '../../services/unlock_state_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/bevel.dart';

/// Opens the unlock-state debug panel. Caller should already have gated the
/// invocation on [kDebugMode] — this helper does not gate again so that
/// widget tests can drive the sheet without needing a release build.
Future<void> showUnlockDebugSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceContainerLow,
    isScrollControlled: true,
    builder: (_) => const UnlockDebugSheet(),
  );
}

class UnlockDebugSheet extends StatelessWidget {
  const UnlockDebugSheet({super.key});

  String _formatHours(int ms) {
    final hours = ms / (3600 * 1000);
    return '${hours.toStringAsFixed(2)}h';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Consumer<UnlockStateService>(
          builder: (context, svc, _) {
            final item = svc.activeItem;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'DEBUG · UNLOCK STATE',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                _ReadoutRow(
                  label: 'Active',
                  value: item == null
                      ? 'none — all 27 unlocked'
                      : '#${svc.activeItemIndex} · ${item.id} (${item.hours}h)',
                ),
                _ReadoutRow(
                  label: 'Progress',
                  value: item == null
                      ? '—'
                      : '${_formatHours(svc.activeAccumulatedMs)} / ${item.hours}h',
                ),
                _ReadoutRow(
                  label: 'Pending',
                  value: svc.pendingClaimIds.isEmpty
                      ? '0'
                      : '${svc.pendingClaimIds.length} · '
                            '${svc.pendingClaimIds.join(", ")}',
                ),
                _ReadoutRow(
                  label: 'Owned',
                  value: '${svc.totalOwnedCount()} '
                      '(${svc.totalUnlockableCount()} unlockable)',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _DebugButton(
                        label: '+1h',
                        onPressed: () => svc.debugAddHours(1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DebugButton(
                        label: '+5h',
                        onPressed: () => svc.debugAddHours(5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DebugButton(
                        label: '+24h',
                        onPressed: () => svc.debugAddHours(24),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _DebugButton(
                  label: 'SKIP ACTIVE',
                  onPressed: item == null ? null : () => svc.debugSkipActive(),
                ),
                const SizedBox(height: 8),
                _DebugButton(
                  label: 'RESET UNLOCK STATE',
                  destructive: true,
                  onPressed: () => _confirmReset(context, svc),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmReset(
    BuildContext context,
    UnlockStateService svc,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset unlock state?'),
        content: Text(
          'Wipes all unlock progress and reseeds the '
          '${kStartingKeyIds.length + kStartingLockIds.length + kStartingKeyColors.length + kStartingLockColors.length}-item '
          'starting loadout.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) await svc.debugReset();
  }
}

class _ReadoutRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReadoutRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DebugButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool destructive;

  const _DebugButton({
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Container(
        decoration: Bevel.raised(
          fill: destructive
              ? AppColors.secondary
              : AppColors.primaryContainer,
        ),
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: destructive
                ? AppColors.surfaceContainerLowest
                : AppColors.onPrimaryContainer,
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}
