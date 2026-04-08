import 'package:flutter/material.dart';
import '../../screens/app_picker_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/bevel.dart';

class AppSelector extends StatefulWidget {
  final List<String> blockedAppPackages;
  final ValueChanged<List<String>> onChanged;

  const AppSelector({
    super.key,
    required this.blockedAppPackages,
    required this.onChanged,
  });

  @override
  State<AppSelector> createState() => _AppSelectorState();
}

class _AppSelectorState extends State<AppSelector> {
  bool _isLoading = false;

  Future<void> _openAppPicker() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final selected = await Navigator.of(context).push<List<String>>(
        MaterialPageRoute(
          builder: (_) => AppPickerScreen(
            initialSelected: widget.blockedAppPackages,
          ),
        ),
      );
      if (selected != null) {
        widget.onChanged(selected);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BLOCKED APPS',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _openAppPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: Bevel.raised(fill: AppColors.surfaceContainerHigh),
            child: Row(
              children: [
                const Icon(Icons.apps, size: 20, color: AppColors.onSurface),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${widget.blockedAppPackages.length} apps blocked',
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryContainer,
                    ),
                  )
                else
                  const Icon(Icons.chevron_right, color: AppColors.outline),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
