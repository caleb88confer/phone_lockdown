import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_blocker_service.dart';
import '../services/platform_channel_service.dart';
import '../theme/app_colors.dart';
import '../theme/bevel.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AppBlockerService>().refreshPermissions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PERMISSIONS',
          style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.w700),
        ),
      ),
      body: Consumer<AppBlockerService>(
        builder: (context, blocker, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Phone Lockdown needs the following permissions to block apps and websites.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              _PermissionTile(
                title: 'Accessibility Service',
                description:
                    'Required to detect when blocked apps are opened and redirect you to the home screen.',
                isGranted: blocker.isAccessibilityEnabled,
                onGrant: () =>
                    context.read<PlatformChannelService>().openAccessibilitySettings(),
              ),
              if (!blocker.isAccessibilityEnabled)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text(
                    'After tapping Grant, look for "Installed apps" or "Downloaded apps" '
                    'at the bottom of the Accessibility page, then find Phone Lockdown and enable it.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ),
              const SizedBox(height: 8),
              _PermissionTile(
                title: 'Device Admin',
                description:
                    'Optional. Prevents the app from being uninstalled while blocking is active.',
                isGranted: blocker.isDeviceAdminEnabled,
                onGrant: () => context.read<PlatformChannelService>().requestDeviceAdmin(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final String title;
  final String description;
  final bool isGranted;
  final VoidCallback onGrant;

  const _PermissionTile({
    required this.title,
    required this.description,
    required this.isGranted,
    required this.onGrant,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: Bevel.raised(fill: AppColors.surfaceContainerLow),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isGranted ? Icons.check_circle : Icons.error,
            color: isGranted ? const Color(0xFF2E7D32) : AppColors.primaryContainer,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isGranted)
            Text(
              'GRANTED',
              style: TextStyle(
                color: const Color(0xFF2E7D32),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            )
          else
            Container(
              decoration: Bevel.raised(fill: AppColors.primaryContainer),
              child: TextButton(
                onPressed: onGrant,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.onPrimaryContainer,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'GRANT',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
