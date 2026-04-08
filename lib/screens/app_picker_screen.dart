import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/platform_channel_service.dart';
import '../theme/app_colors.dart';
import '../theme/bevel.dart';

class AppPickerScreen extends StatefulWidget {
  final List<String> initialSelected;

  const AppPickerScreen({super.key, required this.initialSelected});

  @override
  State<AppPickerScreen> createState() => _AppPickerScreenState();
}

class _AppPickerScreenState extends State<AppPickerScreen> {
  List<Map<String, dynamic>> _allApps = [];
  late Set<String> _selected;
  String _searchQuery = '';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initialSelected);
    _loadApps();
  }

  Future<void> _loadApps() async {
    try {
      final platform = context.read<PlatformChannelService>();
      final apps = await platform.getInstalledApps();
      setState(() {
        _allApps = apps;
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
    if (_searchQuery.isEmpty) return _allApps;
    final query = _searchQuery.toLowerCase();
    return _allApps.where((app) {
      final name = (app['appName'] as String).toLowerCase();
      final pkg = (app['packageName'] as String).toLowerCase();
      return name.contains(query) || pkg.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SELECT APPS TO BLOCK',
          style: TextStyle(letterSpacing: 1.0, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              decoration: Bevel.raised(fill: AppColors.primaryContainer),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(_selected.toList()),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.onPrimaryContainer,
                ),
                child: Text(
                  'DONE (${_selected.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
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
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
      return const Center(child: Text('No apps found'));
    }

    return ListView.builder(
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        final packageName = app['packageName'] as String;
        final appName = app['appName'] as String;
        final iconPath = app['iconPath'] as String?;
        final isSelected = _selected.contains(packageName);

        return Container(
          color: isSelected
              ? AppColors.primaryFixed.withValues(alpha: 0.3)
              : (index.isEven
                  ? AppColors.surfaceContainerLow
                  : AppColors.surface),
          child: ListTile(
            leading: iconPath != null && File(iconPath).existsSync()
                ? Image.file(File(iconPath), width: 40, height: 40)
                : const Icon(Icons.android, size: 40, color: AppColors.outline),
            title: Text(
              appName,
              style: TextStyle(
                color: AppColors.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            subtitle: Text(
              packageName,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Checkbox(
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selected.add(packageName);
                  } else {
                    _selected.remove(packageName);
                  }
                });
              },
            ),
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selected.remove(packageName);
                } else {
                  _selected.add(packageName);
                }
              });
            },
          ),
        );
      },
    );
  }
}
