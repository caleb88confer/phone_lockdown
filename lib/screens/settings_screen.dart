import 'package:flutter/material.dart';
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
        children: const [
          CustomBrowserEditor(),
        ],
      ),
    );
  }
}
