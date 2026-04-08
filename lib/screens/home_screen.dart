import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_blocker_service.dart';
import '../services/profile_manager.dart';
import '../theme/app_colors.dart';
import '../theme/bevel.dart';
import '../widgets/block_button.dart';
import '../widgets/profile_picker.dart';
import 'permissions_screen.dart';
import 'scan_screen.dart';

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

  void _scanCode(BuildContext context) async {
    final appBlocker = context.read<AppBlockerService>();
    final profileManager = context.read<ProfileManager>();

    final scannedValue = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ScanScreen(
          title: appBlocker.isBlocking ? 'Scan to Unlock' : 'Scan to Lock',
          instruction: appBlocker.isBlocking
              ? 'Scan a profile\'s code to unlock it'
              : 'Scan a profile\'s code to activate blocking',
        ),
      ),
    );

    if (!context.mounted || scannedValue == null) return;

    final matchedProfile = profileManager.findProfileByCode(scannedValue);

    if (matchedProfile == null) {
      _showAlert(
        context,
        title: 'Code Not Recognized',
        message: 'No profile is linked to this code. Assign it to a profile in the profile settings.',
      );
      return;
    }

    if (appBlocker.activeProfileIds.contains(matchedProfile.id)) {
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
      return;
    }

    final error = await appBlocker.activateProfile(
      matchedProfile,
      allProfiles: profileManager.profiles,
    );
    if (!context.mounted) return;
    if (error != null) {
      _showAlert(
        context,
        title: 'Cannot Activate Blocking',
        message: error,
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Locked: ${matchedProfile.name}')),
    );
  }

  void _showAlert(BuildContext context,
      {required String title, required String message}) {
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
                margin: const EdgeInsets.only(right: 8),
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
                  child: BlockButton(
                    isBlocking: isBlocking,
                    onTap: () => _scanCode(context),
                  ),
                ),
                if (isBlocking) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ACTIVE PROFILES',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                          final profileColor = Color(profile.colorValue);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: profileColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      profile.name,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.3),
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
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.4),
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
                  const Expanded(
                    flex: 1,
                    child: ProfilePicker(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
