import 'package:flutter/material.dart';
import '../models/profile.dart';
import '../services/profile_manager.dart';

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

  bool get isEditing => widget.profile != null;

  static const _iconOptions = [
    Icons.notifications_off,
    Icons.work,
    Icons.fitness_center,
    Icons.bedtime,
    Icons.school,
    Icons.restaurant,
    Icons.directions_walk,
    Icons.code,
    Icons.music_note,
    Icons.sports_esports,
    Icons.book,
    Icons.flight,
    Icons.beach_access,
    Icons.self_improvement,
    Icons.timer,
    Icons.visibility_off,
    Icons.do_not_disturb,
    Icons.phone_disabled,
    Icons.block,
    Icons.shield,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile?.name ?? '');
    _selectedIconCodePoint =
        widget.profile?.iconCodePoint ?? Icons.notifications_off.codePoint;
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
      );
    } else {
      widget.profileManager.addProfile(
        name: name,
        iconCodePoint: _selectedIconCodePoint,
      );
    }

    Navigator.of(context).pop();
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
          // Profile name
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

          // Icon picker
          Text('Choose Icon',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _iconOptions.map((icon) {
              final isSelected = icon.codePoint == _selectedIconCodePoint;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedIconCodePoint = icon.codePoint;
                }),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.blue.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Icon(icon, size: 24),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Blocked apps (placeholder)
          ListTile(
            title: const Text('Configure Blocked Apps'),
            subtitle: Text(
              '${widget.profile?.blockedAppPackages.length ?? 0} apps blocked',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Implement app picker using Android PackageManager
              // via platform channel to list installed applications.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('App picker coming soon — requires Android platform integration'),
                ),
              );
            },
          ),

          // Delete button (edit mode only)
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
