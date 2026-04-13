import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../screens/browser_picker_screen.dart';
import '../../services/platform_channel_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/bevel.dart';

class CustomBrowserEditor extends StatefulWidget {
  const CustomBrowserEditor({super.key});

  @override
  State<CustomBrowserEditor> createState() => _CustomBrowserEditorState();
}

class _CustomBrowserEditorState extends State<CustomBrowserEditor> {
  List<_BrowserEntry> _browsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final platform = context.read<PlatformChannelService>();
    final packages = await platform.getCustomBrowsers();
    final installed = await platform.getInstalledApps();
    final installedByPkg = {
      for (final b in installed) b['packageName'] as String: b,
    };
    setState(() {
      _browsers = packages.map((pkg) {
        final info = installedByPkg[pkg];
        return _BrowserEntry(
          packageName: pkg,
          appName: info?['appName'] as String? ?? pkg,
          iconPath: info?['iconPath'] as String?,
        );
      }).toList();
      _isLoading = false;
    });
  }

  Future<void> _addBrowser() async {
    final picked = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => BrowserPickerScreen(
          alreadyAdded: _browsers.map((b) => b.packageName).toList(),
        ),
      ),
    );
    if (picked == null || !mounted) return;

    final entry = _BrowserEntry(
      packageName: picked['packageName'] as String,
      appName: picked['appName'] as String,
      iconPath: picked['iconPath'] as String?,
    );
    final next = [..._browsers, entry];
    await _persist(next);
  }

  Future<void> _removeBrowser(String packageName) async {
    final next = _browsers.where((b) => b.packageName != packageName).toList();
    await _persist(next);
  }

  Future<void> _persist(List<_BrowserEntry> next) async {
    final platform = context.read<PlatformChannelService>();
    await platform.updateCustomBrowsers(next.map((b) => b.packageName).toList());
    if (!mounted) return;
    setState(() => _browsers = next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CUSTOM BROWSERS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            Container(
              decoration: Bevel.raised(fill: AppColors.primaryContainer),
              child: IconButton(
                icon: const Icon(
                  Icons.add,
                  color: AppColors.onPrimaryContainer,
                ),
                tooltip: 'Add browser',
                onPressed: _isLoading ? null : _addBrowser,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Add any app that opens URLs (e.g. Vivaldi, Kiwi, in-app browsers). '
          'Built-in Chrome, Firefox, Opera, Edge, Samsung are always monitored.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryContainer,
              ),
            ),
          )
        else if (_browsers.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            color: AppColors.surfaceContainerLow,
            width: double.infinity,
            child: Text(
              'No custom browsers added. Tap + to add one.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
          )
        else
          ..._browsers.asMap().entries.map((entry) {
            final index = entry.key;
            final browser = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 2),
              color: index.isEven
                  ? AppColors.surfaceContainerHigh
                  : AppColors.surfaceContainerLow,
              child: ListTile(
                dense: true,
                leading: browser.iconPath != null &&
                        File(browser.iconPath!).existsSync()
                    ? Image.file(
                        File(browser.iconPath!),
                        width: 32,
                        height: 32,
                      )
                    : const Icon(
                        Icons.public,
                        size: 32,
                        color: AppColors.outline,
                      ),
                title: Text(
                  browser.appName,
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  browser.packageName,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: AppColors.outline,
                  ),
                  onPressed: () => _removeBrowser(browser.packageName),
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _BrowserEntry {
  final String packageName;
  final String appName;
  final String? iconPath;

  _BrowserEntry({
    required this.packageName,
    required this.appName,
    this.iconPath,
  });
}
