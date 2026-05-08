import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/master_key_service.dart';
import '../widgets/settings/custom_browser_editor.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SETTINGS',
          style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CustomBrowserEditor(),
          const SizedBox(height: 24),
          _buildMasterKeyDebugSection(context),
        ],
      ),
    );
  }

  Widget _buildMasterKeyDebugSection(BuildContext context) {
    return Consumer<MasterKeyService>(
      builder: (ctx, mk, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DEBUG',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Master keys: ${mk.count}\n'
              'Total lockdown: ${_formatDuration(mk.totalLockdown)}\n'
              'Toward next key: ${_formatDuration(mk.progressTowardNext)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reset Master Keys (debug)'),
              onPressed: () async {
                await mk.resetForTesting();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Master keys reset — count=3')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }
}
