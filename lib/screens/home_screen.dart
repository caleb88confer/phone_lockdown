import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_blocker_service.dart';
import '../services/nfc_service.dart';
import '../services/profile_manager.dart';
import '../theme/app_colors.dart';
import '../widgets/block_button.dart';
import '../widgets/profile_picker.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _scanTag(BuildContext context) async {
    final nfcService = context.read<NfcService>();
    final appBlocker = context.read<AppBlockerService>();
    final profileManager = context.read<ProfileManager>();

    final payload = await nfcService.scan();

    if (!context.mounted) return;

    if (payload == null) return;

    if (nfcService.isValidBrokeTag(payload)) {
      appBlocker.toggleBlocking(profileManager.currentProfile);
    } else {
      _showAlert(
        context,
        title: 'Not a Broke Tag',
        message: 'You can create a new Broke tag using the + button',
      );
    }
  }

  void _showCreateTagDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Broke Tag'),
        content: const Text('Do you want to create a new Broke tag?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _createTag(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _createTag(BuildContext context) async {
    final nfcService = context.read<NfcService>();
    final success = await nfcService.write(NfcService.tagPhrase);

    if (!context.mounted) return;

    _showAlert(
      context,
      title: 'Tag Creation',
      message: success
          ? 'Broke tag created successfully!'
          : 'Failed to create Broke tag. Please try again.',
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
            title: const Text('Broke'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _showCreateTagDialog(context),
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
                    onTap: () => _scanTag(context),
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
