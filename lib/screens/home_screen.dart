import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../customization/key_catalog.dart';
import '../customization/lock_catalog.dart';
import '../services/app_blocker_service.dart';
import '../services/profile_manager.dart';
import '../theme/app_colors.dart';
import '../theme/bevel.dart';
import '../widgets/block_button.dart';
import '../widgets/stats_info_section.dart';
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
      appBlocker.restoreTimers(profileManager.profilesForBlocker);
      appBlocker.reconcileWithAndroid(profileManager.profilesForBlocker);
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
      _scanToLock(context);
    }
  }

  Future<void> _scanToLock(BuildContext context) async {
    final appBlocker = context.read<AppBlockerService>();
    final profileManager = context.read<ProfileManager>();
    final profile = profileManager.profile;

    final code = profile.unlockCode;
    if (code == null || code.isEmpty) {
      _showAlert(
        context,
        title: 'No Unlock Code',
        message:
            'Cannot lock — no unlock code is set. Tap CUSTOMIZE LOCK to register a key.',
      );
      return;
    }

    final keyStyle = keyStyleById(profile.keyStyleId);
    final keyColor = keyColorForRender(keyStyle, profile.keyColorId);

    final result = await Navigator.of(context).push<ScanResult>(
      MaterialPageRoute(
        builder: (_) => ScanScreen(
          title: 'Scan to Lock',
          keyStyle: keyStyle,
          keyColor: keyColor,
          enableManualLock: true,
        ),
      ),
    );

    if (!context.mounted || result == null) return;

    // Default path: a key was scanned — it must match the registered key.
    if (!result.isManualLock && result.code != code) {
      _showAlert(
        context,
        title: 'Code Not Recognized',
        message: 'That code doesn\'t match your registered key.',
      );
      return;
    }

    final error = await appBlocker.activateProfile(
      profile,
      allProfiles: profileManager.profilesForBlocker,
    );
    if (!context.mounted) return;
    if (error != null) {
      _showAlert(context, title: 'Cannot Activate Blocking', message: error);
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Locked')));
  }

  Future<void> _scanToUnlock(BuildContext context) async {
    final appBlocker = context.read<AppBlockerService>();
    final profileManager = context.read<ProfileManager>();
    final p = profileManager.profile;
    final keyStyle = keyStyleById(p.keyStyleId);
    final keyColor = keyColorForRender(keyStyle, p.keyColorId);

    final result = await Navigator.of(context).push<ScanResult>(
      MaterialPageRoute(
        builder: (_) => ScanScreen(
          title: 'Scan to Unlock',
          instruction: 'Scan your key to unlock',
          keyStyle: keyStyle,
          keyColor: keyColor,
        ),
      ),
    );

    if (!context.mounted || result == null || result.code == null) return;
    final scannedValue = result.code;

    if (p.unlockCode != scannedValue) {
      _showAlert(
        context,
        title: 'Code Not Recognized',
        message: 'That code doesn\'t match your registered key.',
      );
      return;
    }

    final success = await appBlocker.deactivateProfile(
      p.id,
      allProfiles: profileManager.profilesForBlocker,
    );
    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unlocked')));
    }
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
          body: AnimatedContainer(
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
                      final p = profileManager.profile;
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
                Container(
                  height: 2,
                  color: AppColors.outlineVariant.withValues(alpha: 0.3),
                ),
                const Expanded(flex: 1, child: StatsInfoSection()),
              ],
            ),
          ),
        );
      },
    );
  }
}
