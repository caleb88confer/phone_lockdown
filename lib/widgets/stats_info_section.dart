import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../customization/key_catalog.dart';
import '../services/app_blocker_service.dart';
import '../services/master_key_service.dart';
import '../services/profile_manager.dart';
import '../services/unlocked_items_service.dart';
import '../theme/app_colors.dart';
import '../theme/bevel.dart';
import '../utils/app_logger.dart';
import '../utils/duration_format.dart';
import '../widgets/key_display.dart';
import 'profile_form/profile_form_dialog.dart';

class StatsInfoSection extends StatelessWidget {
  const StatsInfoSection({super.key});

  void _openCustomize(BuildContext context) {
    final profileManager = context.read<ProfileManager>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileFormDialog(
          profile: profileManager.profile,
          profileManager: profileManager,
        ),
      ),
    );
  }

  Future<void> _onMasterKeyTap(BuildContext context) async {
    final appBlocker = context.read<AppBlockerService>();
    final profileManager = context.read<ProfileManager>();
    final masterKey = context.read<MasterKeyService>();

    if (masterKey.count == 0) return;
    if (!appBlocker.isBlocking) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Use Master Key?'),
        content: Text(
          'You have ${masterKey.count}.\n\n'
          'This will unlock immediately, no scan needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Use Key'),
          ),
        ],
      ),
    );

    if (!context.mounted || confirmed != true) return;

    final consumed = await masterKey.consume();
    if (!consumed) return;

    try {
      await appBlocker.deactivateProfile(
        profileManager.profile.id,
        allProfiles: profileManager.profilesForBlocker,
      );
    } catch (e) {
      AppLogger.e('MasterKey', 'Failed to deactivate', e);
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Used master key — unlocked')),
    );
  }

  void _openInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('About'),
        content: const Text(
          // TODO: fill in real credits + links (company website, artist pages).
          'Phone Lockdown\n\n'
          'Built to help you take control of your phone usage.\n\n'
          'Credits and links coming soon.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Consumer4<
        AppBlockerService,
        ProfileManager,
        MasterKeyService,
        UnlockedItemsService
      >(
        builder: (context, appBlocker, profileManager, masterKey, unlocked, _) {
          final profile = profileManager.profile;
          final keyStyle = keyStyleById(profile.keyStyleId);
          final keyColor = keyColorForRender(keyStyle, profile.keyColorId);

          // When locked, swap "total locked" for the live countdown.
          final isLocked = appBlocker.isBlocking;
          final lock = isLocked
              ? appBlocker.getLock(profile.id)
              : null;
          final timeLabel = isLocked ? 'TIME TILL UNLOCK' : 'TOTAL LOCKED';
          final timeValue = isLocked
              ? formatDurationShort(lock?.remaining ?? Duration.zero)
              : formatDurationShort(masterKey.totalLockdown);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'STATS',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  Container(
                    decoration: Bevel.raised(
                      fill: AppColors.surfaceContainerHigh,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.help_outline, size: 20),
                      tooltip: 'About',
                      onPressed: () => _openInfo(context),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Center(
                        child: KeyDisplay(
                          style: keyStyle,
                          color: keyColor,
                          size: 110,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _StatRow(label: timeLabel, value: timeValue),
                          const SizedBox(height: 12),
                          _StatRow(
                            label: 'MASTER KEYS',
                            value: '${masterKey.count} / 3',
                            onTap: (isLocked && masterKey.count > 0)
                                ? () => _onMasterKeyTap(context)
                                : null,
                          ),
                          const SizedBox(height: 12),
                          _StatRow(
                            label: 'UNLOCKED ITEMS',
                            value:
                                '${unlocked.unlockedCount} / ${unlocked.totalCount}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: Bevel.raised(fill: AppColors.primaryContainer),
                  child: TextButton(
                    onPressed: () => _openCustomize(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.onPrimaryContainer,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'CUSTOMIZE LOCK',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _StatRow({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.touch_app,
                size: 12,
                color: AppColors.primaryContainer,
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
            color: onTap != null
                ? AppColors.primaryContainer
                : AppColors.onSurface,
          ),
        ),
      ],
    );

    if (onTap == null) return content;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}
