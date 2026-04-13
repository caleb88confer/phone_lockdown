import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/platform_channel_service.dart';
import '../theme/app_colors.dart';
import '../theme/bevel.dart';

const Set<String> _kBuiltinBrowsers = {
  'com.android.chrome',
  'org.mozilla.firefox',
  'com.opera.browser',
  'com.microsoft.emmx',
  'com.samsung.android.app.sbrowser',
};

class BrowserPickerScreen extends StatefulWidget {
  final List<String> alreadyAdded;

  const BrowserPickerScreen({super.key, required this.alreadyAdded});

  @override
  State<BrowserPickerScreen> createState() => _BrowserPickerScreenState();
}

class _BrowserPickerScreenState extends State<BrowserPickerScreen> {
  List<Map<String, dynamic>> _apps = [];
  String _searchQuery = '';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    try {
      final platform = context.read<PlatformChannelService>();
      final apps = await platform.getInstalledApps();
      setState(() {
        _apps = apps;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load apps: $e';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredApps {
    final alreadyAdded = widget.alreadyAdded.toSet();
    final query = _searchQuery.toLowerCase();
    return _apps.where((app) {
      final pkg = app['packageName'] as String;
      if (alreadyAdded.contains(pkg)) return false;
      if (_kBuiltinBrowsers.contains(pkg)) return false;
      if (query.isEmpty) return true;
      final name = (app['appName'] as String).toLowerCase();
      return name.contains(query) || pkg.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ADD BROWSER-LIKE APP',
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
      body: Column(
        children: [
          const _WarningBanner(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              decoration: Bevel.sunken(),
              child: TextField(
                style: const TextStyle(color: AppColors.onSurface),
                decoration: const InputDecoration(
                  hintText: 'Search apps...',
                  prefixIcon: Icon(Icons.search, color: AppColors.outline),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
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

    final apps = _filteredApps;
    if (apps.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No matching apps.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        final packageName = app['packageName'] as String;
        final appName = app['appName'] as String;
        final iconPath = app['iconPath'] as String?;

        return Container(
          color: index.isEven
              ? AppColors.surfaceContainerLow
              : AppColors.surface,
          child: ListTile(
            leading: iconPath != null && File(iconPath).existsSync()
                ? Image.file(File(iconPath), width: 40, height: 40)
                : const Icon(Icons.android, size: 40, color: AppColors.outline),
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
                onPressed: () => Navigator.of(context).pop(app),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.onPrimaryContainer,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
            onTap: () => Navigator.of(context).pop(app),
          ),
        );
      },
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: Bevel.raised(fill: AppColors.surfaceContainerLow),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.primaryContainer,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Only add apps that show URLs in a URL bar. Adding non-browsers '
              'may cause false blocks when the app\'s text contains a domain '
              '(e.g. "check out tiktok.com" in Messages).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
