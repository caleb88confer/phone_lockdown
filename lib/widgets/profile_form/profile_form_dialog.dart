import 'package:flutter/material.dart';
import '../../customization/key_catalog.dart';
import '../../customization/lock_catalog.dart';
import '../../models/profile.dart';
import '../../screens/scan_screen.dart';
import '../../services/profile_manager.dart';
import '../../theme/app_colors.dart';
import '../../theme/bevel.dart';
import 'app_selector.dart';
import 'failsafe_selector.dart';
import 'set_key_section.dart';
import 'set_lock_section.dart';
import 'website_editor.dart';

class ProfileFormDialog extends StatefulWidget {
  final Profile profile;
  final ProfileManager profileManager;

  const ProfileFormDialog({
    super.key,
    required this.profile,
    required this.profileManager,
  });

  @override
  State<ProfileFormDialog> createState() => _ProfileFormDialogState();
}

class _ProfileFormDialogState extends State<ProfileFormDialog> {
  late String _lockStyleId;
  late String _lockColorId;
  late String _keyStyleId;
  late String _keyColorId;
  late List<String> _blockedAppPackages;
  late List<String> _blockedWebsites;
  late String? _unlockCode;
  late int _failsafeMinutes;

  @override
  void initState() {
    super.initState();
    _lockStyleId = widget.profile.lockStyleId;
    _lockColorId = widget.profile.lockColorId;
    _keyStyleId = widget.profile.keyStyleId;
    _keyColorId = widget.profile.keyColorId;
    _blockedAppPackages = List<String>.from(widget.profile.blockedAppPackages);
    _blockedWebsites = List<String>.from(widget.profile.blockedWebsites);
    _unlockCode = widget.profile.unlockCode;
    _failsafeMinutes = widget.profile.failsafeMinutes;
  }

  void _onLockStyleChanged(String id) {
    setState(() {
      _lockStyleId = id;
      final available = lockStyleById(id).colors;
      if (!available.any((c) => c.id == _lockColorId)) {
        _lockColorId = available.first.id;
      }
    });
  }

  void _onKeyStyleChanged(String id) {
    setState(() => _keyStyleId = id);
  }

  void _handleSave() {
    widget.profileManager.updateProfile(
      lockStyleId: _lockStyleId,
      lockColorId: _lockColorId,
      keyStyleId: _keyStyleId,
      keyColorId: _keyColorId,
      blockedAppPackages: _blockedAppPackages,
      blockedWebsites: _blockedWebsites,
      unlockCode: _unlockCode,
      clearUnlockCode: _unlockCode == null && widget.profile.unlockCode != null,
      failsafeMinutes: _failsafeMinutes,
    );
    Navigator.of(context).pop();
  }

  void _scanUnlockCode() async {
    final keyStyle = keyStyleById(_keyStyleId);
    final keyColor = keyColorForRender(keyStyle, _keyColorId);
    final result = await Navigator.of(context).push<ScanResult>(
      MaterialPageRoute(
        builder: (_) => ScanScreen(
          title: 'Register Code',
          instruction: 'Scan the QR code or barcode to use as your key',
          keyStyle: keyStyle,
          keyColor: keyColor,
        ),
      ),
    );

    if (!mounted || result == null || result.code == null) return;

    setState(() {
      _unlockCode = result.code;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('SETUP'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              decoration: Bevel.raised(fill: AppColors.primaryContainer),
              child: TextButton(
                onPressed: _handleSave,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.onPrimaryContainer,
                ),
                child: const Text(
                  'SAVE',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Set Key section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: Bevel.ghost(
              fill: AppColors.surfaceContainerLow,
              opacity: 0.2,
            ),
            child: SetKeySection(
              unlockCode: _unlockCode,
              onScan: _scanUnlockCode,
              onClear: () => setState(() => _unlockCode = null),
              selectedStyleId: _keyStyleId,
              selectedColorId: _keyColorId,
              onStyleChanged: _onKeyStyleChanged,
              onColorChanged: (id) => setState(() => _keyColorId = id),
            ),
          ),
          const SizedBox(height: 16),

          // Lock picker section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: Bevel.ghost(
              fill: AppColors.surfaceContainerLow,
              opacity: 0.2,
            ),
            child: SetLockSection(
              selectedStyleId: _lockStyleId,
              selectedColorId: _lockColorId,
              onStyleChanged: _onLockStyleChanged,
              onColorChanged: (id) => setState(() => _lockColorId = id),
            ),
          ),
          const SizedBox(height: 16),

          // Blocked Apps section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: Bevel.ghost(
              fill: AppColors.surfaceContainerLow,
              opacity: 0.2,
            ),
            child: AppSelector(
              blockedAppPackages: _blockedAppPackages,
              onChanged: (selected) => setState(() {
                _blockedAppPackages = selected;
              }),
            ),
          ),
          const SizedBox(height: 16),

          // Blocked Websites section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: Bevel.ghost(
              fill: AppColors.surfaceContainerLow,
              opacity: 0.2,
            ),
            child: WebsiteEditor(
              blockedWebsites: _blockedWebsites,
              onChanged: (websites) => setState(() {
                _blockedWebsites = websites;
              }),
            ),
          ),
          const SizedBox(height: 16),

          // Failsafe section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: Bevel.ghost(
              fill: AppColors.surfaceContainerLow,
              opacity: 0.2,
            ),
            child: FailsafeSelector(
              failsafeMinutes: _failsafeMinutes,
              onChanged: (minutes) => setState(() {
                _failsafeMinutes = minutes;
              }),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
