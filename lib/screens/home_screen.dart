import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_blocker_service.dart';
import '../services/profile_manager.dart';
import '../theme/app_colors.dart';
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
    // Restore timers once profiles are loaded
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

    // If this profile is currently active, deactivate it
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

    // Activate this profile
    final success = await appBlocker.activateProfile(
      matchedProfile,
      allProfiles: profileManager.profiles,
    );
    if (!context.mounted) return;
    if (!success) {
      _showAlert(
        context,
        title: 'Accessibility Service Required',
        message: 'Please enable the Phone Lockdown accessibility service in Settings to block apps.',
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
            title: const Text('Phone Lockdown'),
            actions: [
              IconButton(
                icon: const Icon(Icons.security),
                tooltip: 'Permissions',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PermissionsScreen(),
                    ),
                  );
                },
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
                  // Show active profiles with countdown timers
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active Profiles',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.7),
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
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    IconData(profile.iconCodePoint,
                                        fontFamily: 'MaterialIcons'),
                                    size: 20,
                                    color: Colors.red.shade300,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      profile.name,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 16,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDuration(lock.remaining),
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontFamily: 'monospace',
                                      fontSize: 13,
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
                  const Divider(height: 1),
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
