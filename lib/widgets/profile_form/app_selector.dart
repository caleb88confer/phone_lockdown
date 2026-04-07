import 'package:flutter/material.dart';
import '../../screens/app_picker_screen.dart';

class AppSelector extends StatelessWidget {
  final List<String> blockedAppPackages;
  final ValueChanged<List<String>> onChanged;

  const AppSelector({
    super.key,
    required this.blockedAppPackages,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('Configure Blocked Apps'),
      subtitle: Text('${blockedAppPackages.length} apps blocked'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final selected = await Navigator.of(context).push<List<String>>(
          MaterialPageRoute(
            builder: (_) => AppPickerScreen(
              initialSelected: blockedAppPackages,
            ),
          ),
        );
        if (selected != null) {
          onChanged(selected);
        }
      },
    );
  }
}
