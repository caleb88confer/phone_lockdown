import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants.dart';
import '../../models/profile.dart';
import '../../screens/scan_screen.dart';
import '../../services/app_blocker_service.dart';
import '../../services/profile_manager.dart';
import '../../theme/app_colors.dart';
import '../../theme/bevel.dart';
import 'app_selector.dart';
import 'color_picker.dart';
import 'failsafe_selector.dart';
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
  late int _selectedColorValue;
  late List<String> _blockedAppPackages;
  late List<String> _blockedWebsites;
  late String? _unlockCode;
  late int _failsafeMinutes;

  bool get isEditing => widget.profile != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile?.name ?? '');
    _selectedColorValue =
        widget.profile?.colorValue ?? 0xFFFFB800;
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
        colorValue: _selectedColorValue,
        blockedAppPackages: _blockedAppPackages,
        blockedWebsites: _blockedWebsites,
        unlockCode: _unlockCode,
        clearUnlockCode: _unlockCode == null && widget.profile?.unlockCode != null,
        failsafeMinutes: _failsafeMinutes,
      );
    } else {
      final profile = Profile(
        name: name,
        colorValue: _selectedColorValue,
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
            onPressed: () async {
              final appBlocker = context.read<AppBlockerService>();
              await appBlocker.onProfileDeleted(
                widget.profile!.id,
                allProfiles: widget.profileManager.profiles,
              );
              widget.profileManager.deleteProfile(widget.profile!.id);
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.secondary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(isEditing ? 'EDIT PROFILE' : 'NEW PROFILE'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              decoration: _nameController.text.trim().isEmpty
                  ? null
                  : Bevel.raised(fill: AppColors.primaryContainer),
              child: TextButton(
                onPressed: _nameController.text.trim().isEmpty ? null : _handleSave,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.onPrimaryContainer,
                  disabledForegroundColor: AppColors.outline,
                ),
                child: Text(
                  'SAVE',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: _nameController.text.trim().isEmpty
                        ? AppColors.outline
                        : AppColors.onPrimaryContainer,
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
          // Profile Name section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: Bevel.ghost(
              fill: AppColors.surfaceContainerLow,
              opacity: 0.2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PROFILE NAME',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: Bevel.sunken(),
                  child: TextField(
                    controller: _nameController,
                    style: const TextStyle(color: AppColors.onSurface),
                    decoration: const InputDecoration(
                      hintText: 'Enter profile name',
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Color Picker section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: Bevel.ghost(
              fill: AppColors.surfaceContainerLow,
              opacity: 0.2,
            ),
            child: ProfileColorPicker(
              selectedColorValue: _selectedColorValue,
              onColorSelected: (colorValue) => setState(() {
                _selectedColorValue = colorValue;
              }),
            ),
          ),
          const SizedBox(height: 16),

          // Unlock Code section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: Bevel.ghost(
              fill: AppColors.surfaceContainerLow,
              opacity: 0.2,
            ),
            child: UnlockCodeSection(
              unlockCode: _unlockCode,
              onScan: _scanUnlockCode,
              onClear: () => setState(() => _unlockCode = null),
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

          if (isEditing) ...[
            const SizedBox(height: 32),
            Container(
              decoration: Bevel.raised(fill: AppColors.surfaceContainerHigh),
              child: TextButton(
                onPressed: _handleDelete,
                child: Text(
                  'DELETE PROFILE',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
