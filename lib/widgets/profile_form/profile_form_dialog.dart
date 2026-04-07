import 'package:flutter/material.dart';
import '../../constants.dart';
import '../../models/profile.dart';
import '../../screens/scan_screen.dart';
import '../../services/profile_manager.dart';
import 'app_selector.dart';
import 'failsafe_selector.dart';
import 'icon_picker.dart';
import 'unlock_code_section.dart';
import 'website_editor.dart';

class ProfileFormDialog extends StatefulWidget {
  final Profile? profile;
  final ProfileManager profileManager;

  const ProfileFormDialog({
    super.key,
    this.profile,
    required this.profileManager,
  });

  @override
  State<ProfileFormDialog> createState() => _ProfileFormDialogState();
}

class _ProfileFormDialogState extends State<ProfileFormDialog> {
  late TextEditingController _nameController;
  late int _selectedIconCodePoint;
  late List<String> _blockedAppPackages;
  late List<String> _blockedWebsites;
  late String? _unlockCode;
  late int _failsafeMinutes;

  bool get isEditing => widget.profile != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile?.name ?? '');
    _selectedIconCodePoint =
        widget.profile?.iconCodePoint ?? Icons.notifications_off.codePoint;
    _blockedAppPackages =
        List<String>.from(widget.profile?.blockedAppPackages ?? []);
    _blockedWebsites = List<String>.from(widget.profile?.blockedWebsites ?? []);
    _unlockCode = widget.profile?.unlockCode;
    _failsafeMinutes = widget.profile?.failsafeMinutes ?? kDefaultFailsafeMinutes;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    if (isEditing) {
      widget.profileManager.updateProfile(
        id: widget.profile!.id,
        name: name,
        iconCodePoint: _selectedIconCodePoint,
        blockedAppPackages: _blockedAppPackages,
        blockedWebsites: _blockedWebsites,
        unlockCode: _unlockCode,
        clearUnlockCode: _unlockCode == null && widget.profile?.unlockCode != null,
        failsafeMinutes: _failsafeMinutes,
      );
    } else {
      final profile = Profile(
        name: name,
        iconCodePoint: _selectedIconCodePoint,
        blockedAppPackages: _blockedAppPackages,
        blockedWebsites: _blockedWebsites,
        unlockCode: _unlockCode,
        failsafeMinutes: _failsafeMinutes,
      );
      widget.profileManager.addProfileInstance(profile);
    }

    Navigator.of(context).pop();
  }

  void _scanUnlockCode() async {
    final scannedValue = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const ScanScreen(
          title: 'Register Code',
          instruction: 'Scan the QR code or barcode to use as this profile\'s key',
        ),
      ),
    );

    if (!mounted || scannedValue == null) return;

    final existingProfile = widget.profileManager.findProfileByCode(scannedValue);
    if (existingProfile != null && existingProfile.id != widget.profile?.id) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Code Already Used'),
          content: Text('This code is already assigned to "${existingProfile.name}". Each profile needs a unique code.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      _unlockCode = scannedValue;
    });
  }

  void _handleDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Profile'),
        content: const Text('Are you sure you want to delete this profile?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              widget.profileManager.deleteProfile(widget.profile!.id);
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Profile' : 'Add Profile'),
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        actions: [
          TextButton(
            onPressed: _nameController.text.trim().isEmpty ? null : _handleSave,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Profile Name',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: 'Enter profile name',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),

          IconPicker(
            selectedIconCodePoint: _selectedIconCodePoint,
            onIconSelected: (codePoint) => setState(() {
              _selectedIconCodePoint = codePoint;
            }),
          ),
          const SizedBox(height: 24),

          UnlockCodeSection(
            unlockCode: _unlockCode,
            onScan: _scanUnlockCode,
            onClear: () => setState(() => _unlockCode = null),
          ),
          const SizedBox(height: 24),

          AppSelector(
            blockedAppPackages: _blockedAppPackages,
            onChanged: (selected) => setState(() {
              _blockedAppPackages = selected;
            }),
          ),
          const SizedBox(height: 24),

          WebsiteEditor(
            blockedWebsites: _blockedWebsites,
            onChanged: (websites) => setState(() {
              _blockedWebsites = websites;
            }),
          ),
          const SizedBox(height: 24),

          FailsafeSelector(
            failsafeMinutes: _failsafeMinutes,
            onChanged: (minutes) => setState(() {
              _failsafeMinutes = minutes;
            }),
          ),

          if (isEditing) ...[
            const SizedBox(height: 32),
            TextButton(
              onPressed: _handleDelete,
              child: const Text(
                'Delete Profile',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
