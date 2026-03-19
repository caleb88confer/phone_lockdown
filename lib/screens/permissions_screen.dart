import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_blocker_service.dart';
import '../services/platform_channel_service.dart';

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
      appBar: AppBar(title: const Text('Permissions')),
      body: Consumer<AppBlockerService>(
        builder: (context, blocker, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Phone Lockdown needs the following permissions to block apps and websites.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              _PermissionTile(
                title: 'Accessibility Service',
                description:
                    'Required to detect when blocked apps are opened and redirect you to the home screen.',
                isGranted: blocker.isAccessibilityEnabled,
                onGrant: () =>
                    PlatformChannelService.openAccessibilitySettings(),
              ),
              if (!blocker.isAccessibilityEnabled)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text(
                    'After tapping Grant, look for "Installed apps" or "Downloaded apps" '
                    'at the bottom of the Accessibility page, then find Phone Lockdown and enable it.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
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
                onGrant: () => PlatformChannelService.requestDeviceAdmin(),
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
    return Card(
      child: ListTile(
        leading: Icon(
          isGranted ? Icons.check_circle : Icons.error,
          color: isGranted ? Colors.green : Colors.orange,
          size: 32,
        ),
        title: Text(title),
        subtitle: Text(description),
        trailing: isGranted
            ? const Text('Granted', style: TextStyle(color: Colors.green))
            : ElevatedButton(
                onPressed: onGrant,
                child: const Text('Grant'),
              ),
      ),
    );
  }
}
