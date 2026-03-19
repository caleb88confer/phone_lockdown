import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_blocker_service.dart';
import '../services/code_scan_service.dart';
import '../services/profile_manager.dart';
import '../theme/app_colors.dart';
import '../widgets/block_button.dart';
import '../widgets/profile_picker.dart';
import 'permissions_screen.dart';
import 'scan_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _scanCode(BuildContext context) async {
    final codeScanService = context.read<CodeScanService>();
    final appBlocker = context.read<AppBlockerService>();
    final profileManager = context.read<ProfileManager>();

    if (!codeScanService.hasRegisteredCode) {
      _showAlert(
        context,
        title: 'No Code Registered',
        message:
            'You need to register a QR code or barcode first. Use the + button to set one up.',
      );
      return;
    }

    final scannedValue = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const ScanScreen(
          title: 'Scan to Toggle',
          instruction: 'Scan your registered code to lock or unlock',
        ),
      ),
    );

    if (!context.mounted || scannedValue == null) return;

    if (codeScanService.isValidCode(scannedValue)) {
      final success =
          await appBlocker.toggleBlocking(profileManager.currentProfile);
      if (!context.mounted) return;
      if (!success) {
        _showAlert(
          context,
          title: 'Accessibility Service Required',
          message:
              'Please enable the Phone Lockdown accessibility service in Settings to block apps.',
        );
        return;
      }
    } else {
      _showAlert(
        context,
        title: 'Code Not Recognized',
        message:
            'This code does not match your registered code. Use the + button to register a new one.',
      );
    }
  }

  void _showRegisterCodeDialog(BuildContext context) {
    final codeScanService = context.read<CodeScanService>();
    final hasCode = codeScanService.hasRegisteredCode;
    final codePreview = hasCode
        ? '${codeScanService.registeredCode!.substring(0, codeScanService.registeredCode!.length.clamp(0, 8))}...'
        : null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlock Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasCode) ...[
              const Text('Current code:'),
              const SizedBox(height: 4),
              Text(codePreview!, style: const TextStyle(fontFamily: 'monospace', fontSize: 16)),
              const SizedBox(height: 16),
            ],
            const Text('Scan a QR code or barcode to use as your lock/unlock key.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          if (hasCode)
            TextButton(
              onPressed: () {
                codeScanService.clearRegisteredCode();
                Navigator.of(ctx).pop();
              },
              child: const Text('Clear Code', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _registerCode(context);
            },
            child: Text(hasCode ? 'Change Code' : 'Scan'),
          ),
        ],
      ),
    );
  }

  void _registerCode(BuildContext context) async {
    final codeScanService = context.read<CodeScanService>();

    final scannedValue = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const ScanScreen(
          title: 'Register Code',
          instruction: 'Scan the QR code or barcode you want to use as your key',
        ),
      ),
    );

    if (!context.mounted || scannedValue == null) return;

    await codeScanService.registerCode(scannedValue);

    if (!context.mounted) return;

    _showAlert(
      context,
      title: 'Code Registered',
      message: 'Your unlock code has been saved. Scan it again to toggle blocking.',
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

  @override
  Widget build(BuildContext context) {
    return Consumer<AppBlockerService>(
      builder: (context, appBlocker, _) {
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
              IconButton(
                icon: const Icon(Icons.vpn_key),
                tooltip: 'Manage unlock code',
                onPressed: () => _showRegisterCodeDialog(context),
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
                  flex: isBlocking ? 1 : 1,
                  child: BlockButton(
                    isBlocking: isBlocking,
                    onTap: () => _scanCode(context),
                  ),
                ),
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
