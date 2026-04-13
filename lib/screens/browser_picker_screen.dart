import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/platform_channel_service.dart';
import '../theme/app_colors.dart';
import '../theme/bevel.dart';

class BrowserPickerScreen extends StatefulWidget {
  final List<String> alreadyAdded;

  const BrowserPickerScreen({super.key, required this.alreadyAdded});

  @override
  State<BrowserPickerScreen> createState() => _BrowserPickerScreenState();
}

class _BrowserPickerScreenState extends State<BrowserPickerScreen> {
  List<Map<String, dynamic>> _browsers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBrowsers();
  }

  Future<void> _loadBrowsers() async {
    try {
      final platform = context.read<PlatformChannelService>();
      final browsers = await platform.getInstalledBrowsers();
      setState(() {
        _browsers = browsers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load browsers: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ADD CUSTOM BROWSER',
          style: TextStyle(
            letterSpacing: 1.0,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryContainer),
      );
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }

    final alreadyAdded = widget.alreadyAdded.toSet();
    final available = _browsers
        .where((b) => !alreadyAdded.contains(b['packageName'] as String))
        .toList();

    if (available.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No additional browsers found on this device. '
            'All installed browsers are either built-in or already added.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: available.length,
      itemBuilder: (context, index) {
        final browser = available[index];
        final packageName = browser['packageName'] as String;
        final appName = browser['appName'] as String;
        final iconPath = browser['iconPath'] as String?;

        return Container(
          color: index.isEven
              ? AppColors.surfaceContainerLow
              : AppColors.surface,
          child: ListTile(
            leading: iconPath != null && File(iconPath).existsSync()
                ? Image.file(File(iconPath), width: 40, height: 40)
                : const Icon(Icons.public, size: 40, color: AppColors.outline),
            title: Text(
              appName,
              style: const TextStyle(color: AppColors.onSurface),
            ),
            subtitle: Text(
              packageName,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Container(
              decoration: Bevel.raised(fill: AppColors.primaryContainer),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(browser),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.onPrimaryContainer,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'ADD',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            onTap: () => Navigator.of(context).pop(browser),
          ),
        );
      },
    );
  }
}
