import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../customization/key_catalog.dart';
import '../customization/lock_catalog.dart';
import '../services/app_blocker_service.dart';
import '../services/master_key_service.dart';
import '../services/profile_manager.dart';
import '../theme/app_colors.dart';
import '../theme/bevel.dart';
import '../utils/app_logger.dart';
import '../widgets/block_button.dart';
import '../widgets/master_key_display.dart';
import '../widgets/profile_picker.dart';
import '../widgets/sprite_sheet.dart';
import 'permissions_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appBlocker = context.read<AppBlockerService>();
      final profileManager = context.read<ProfileManager>();
      appBlocker.restoreTimers(profileManager.profiles);
      appBlocker.reconcileWithAndroid(profileManager.profiles);
    });
    _startCountdownRefresh();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownRefresh() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onLockButtonTap(BuildContext context) {
    final appBlocker = context.read<AppBlockerService>();
    if (appBlocker.isBlocking) {
      _scanToUnlock(context);
    } else {
      _manualLock(context);
    }
  }

  Future<void> _manualLock(BuildContext context) async {
    final appBlocker = context.read<AppBlockerService>();
    final profileManager = context.read<ProfileManager>();
    final profile = profileManager.currentProfile;

    final code = profile.unlockCode;
    if (code == null || code.isEmpty) {
      _showAlert(
        context,
        title: 'No Unlock Code',
        message:
            'Cannot lock — the current profile (${profile.name}) has no unlock code. Set one in profile settings before locking.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lock Now?'),
        content: Text(
          'Profile: ${profile.name}\n'
          'Failsafe: ${_formatDuration(Duration(minutes: profile.failsafeMinutes))}\n\n'
          'Scan your key to unlock early.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Lock'),
          ),
        ],
      ),
    );

    if (!context.mounted || confirmed != true) return;

    final error = await appBlocker.activateProfile(
      profile,
      allProfiles: profileManager.profiles,
    );
    if (!context.mounted) return;
    if (error != null) {
      _showAlert(context, title: 'Cannot Activate Blocking', message: error);
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Locked: ${profile.name}')));
  }

  Future<void> _scanToUnlock(BuildContext context) async {
    final appBlocker = context.read<AppBlockerService>();
    final profileManager = context.read<ProfileManager>();
    final p = profileManager.currentProfile;
    final keyStyle = keyStyleById(p.keyStyleId);
    final keyColor = keyColorForRender(keyStyle, p.keyColorId);

    final scannedValue = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ScanScreen(
          title: 'Scan to Unlock',
          instruction: 'Scan a profile\'s code to unlock it',
          keyStyle: keyStyle,
          keyColor: keyColor,
        ),
      ),
    );

    if (!context.mounted || scannedValue == null) return;

    final matchedProfile = profileManager.findProfileByCode(scannedValue);

    if (matchedProfile == null) {
      _showAlert(
        context,
        title: 'Code Not Recognized',
        message: 'No profile is linked to this code.',
      );
      return;
    }

    if (!appBlocker.activeProfileIds.contains(matchedProfile.id)) {
      _showAlert(
        context,
        title: 'Profile Not Active',
        message:
            '${matchedProfile.name} is not currently locked, so this key has nothing to unlock.',
      );
      return;
    }

    final success = await appBlocker.deactivateProfile(
      matchedProfile.id,
      allProfiles: profileManager.profiles,
    );
    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unlocked: ${matchedProfile.name}')),
      );
    }
  }

  Future<void> _onMasterKeyTap(BuildContext context) async {
    final appBlocker = context.read<AppBlockerService>();
    final profileManager = context.read<ProfileManager>();
    final masterKey = context.read<MasterKeyService>();

    if (masterKey.count == 0) return;
    if (!appBlocker.isBlocking) return;

    // Snapshot which profiles will be unlocked, before async gaps mutate state.
    final activeIds = appBlocker.activeProfileIds.toList();
    final activeNames = activeIds.map((id) {
      final profile = profileManager.profiles.cast<dynamic>().firstWhere(
        (p) => p.id == id,
        orElse: () => null,
      );
      return profile?.name as String? ?? 'Unknown';
    }).toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Use Master Key?'),
        content: Text(
          'You have ${masterKey.count}.\n\n'
          'This will unlock all ${activeIds.length} locked profile'
          '${activeIds.length == 1 ? '' : 's'} (${activeNames.join(', ')}) '
          'immediately, no scan needed.',
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

    int unlocked = 0;
    for (final id in activeIds) {
      try {
        final ok = await appBlocker.deactivateProfile(
          id,
          allProfiles: profileManager.profiles,
        );
        if (ok) unlocked++;
      } catch (e) {
        AppLogger.e('MasterKey', 'Failed to deactivate profile $id', e);
      }
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Used master key — unlocked $unlocked profile'
          '${unlocked == 1 ? '' : 's'}',
        ),
      ),
    );
  }

  void _showAlert(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AppBlockerService, ProfileManager>(
      builder: (context, appBlocker, profileManager, _) {
        final isBlocking = appBlocker.isBlocking;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'PHONE LOCKDOWN',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 4),
                decoration: Bevel.raised(fill: AppColors.surfaceContainerHigh),
                child: IconButton(
                  icon: const Icon(Icons.security, size: 20),
                  tooltip: 'Permissions',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PermissionsScreen(),
                      ),
                    );
                  },
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: Bevel.raised(fill: AppColors.surfaceContainerHigh),
                child: IconButton(
                  icon: const Icon(Icons.settings, size: 20),
                  tooltip: 'Settings',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                color: isBlocking
                    ? AppColors.blockingBackground
                    : AppColors.nonBlockingBackground,
                child: Column(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Builder(
                        builder: (_) {
                          final p = profileManager.currentProfile;
                          final style = lockStyleById(p.lockStyleId);
                          final color = lockColorById(style, p.lockColorId);
                          final keyStyle = keyStyleById(p.keyStyleId);
                          final keyColor = keyColorForRender(
                            keyStyle,
                            p.keyColorId,
                          );
                          return BlockButton(
                            isBlocking: isBlocking,
                            onTap: () => _onLockButtonTap(context),
                            lockStyle: style,
                            lockColor: color,
                            keyStyle: keyStyle,
                            keyColor: keyColor,
                          );
                        },
                      ),
                    ),
                    if (isBlocking) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ACTIVE PROFILES',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            ...appBlocker.activeProfileIds.map((profileId) {
                              final lock = appBlocker.getLock(profileId);
                              final profile = profileManager.profiles
                                  .cast<dynamic>()
                                  .firstWhere(
                                    (p) => p.id == profileId,
                                    orElse: () => null,
                                  );
                              if (lock == null || profile == null) {
                                return const SizedBox.shrink();
                              }
                              final lockStyle = lockStyleById(
                                profile.lockStyleId,
                              );
                              final lockColor = lockColorById(
                                lockStyle,
                                profile.lockColorId,
                              );
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                  child: Row(
                                    children: [
                                      SpriteFrame(
                                        assetPath: lockStyle.spritesheetPath(
                                          lockColor.id,
                                        ),
                                        frameWidth: lockStyle.frameWidth,
                                        frameHeight: lockStyle.frameHeight,
                                        frameIndex: lockStyle.lockedFrame,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          profile.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.timer_outlined,
                                        size: 16,
                                        color: AppColors.primaryContainer,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatDuration(lock.remaining),
                                        style: TextStyle(
                                          color: AppColors.primaryContainer,
                                          fontFamily: 'monospace',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 4),
                            Center(
                              child: Text(
                                'Scan a profile\'s code to unlock it',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (!isBlocking) ...[
                      Container(
                        height: 2,
                        color: AppColors.outlineVariant.withValues(alpha: 0.3),
                      ),
                      const Expanded(flex: 1, child: ProfilePicker()),
                    ],
                  ],
                ),
              ),
              if (isBlocking)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: SafeArea(
                    child: MasterKeyInventory(
                      onTap: () => _onMasterKeyTap(context),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
