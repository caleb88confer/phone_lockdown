import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/platform_channel_service.dart';

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
        title: const Text('Select Apps to Block'),
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_selected.toList()),
            child: Text('Done (${_selected.length})'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search apps...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
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
        final iconBase64 = app['icon'] as String;
        final isSelected = _selected.contains(packageName);

        Uint8List? iconBytes;
        try {
          iconBytes = base64Decode(iconBase64);
        } catch (_) {
          iconBytes = null;
        }

        return ListTile(
          leading: iconBytes != null
              ? Image.memory(iconBytes, width: 40, height: 40)
              : const Icon(Icons.android, size: 40),
          title: Text(appName),
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
        );
      },
    );
  }
}
