# Code Smells Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Clean up three code smells: decompose ProfileFormDialog, centralize constants, and rename the package from `com.example.phone_lockdown` to `app.phonelockdown`.

**Architecture:** Extract ProfileFormDialog sub-widgets into `lib/widgets/profile_form/` using lifted-state-up pattern. Create `lib/constants.dart` and `Constants.kt` for shared magic strings/numbers. Rename Android package by moving Kotlin files, updating `build.gradle.kts`, and fixing all package/import declarations.

**Tech Stack:** Flutter/Dart, Kotlin, Android

---

### Task 1: Create Flutter Constants File

**Files:**
- Create: `lib/constants.dart`

- [ ] **Step 1: Create `lib/constants.dart`**

```dart
// Method channel
const kMethodChannel = 'app.phonelockdown/blocker';

// SharedPreferences keys
const kPrefSavedProfiles = 'savedProfiles';
const kPrefCurrentProfileId = 'currentProfileId';
const kPrefActiveLocks = 'activeLocks';
const kPrefIsBlocking = 'isBlocking';

// Defaults
const kDefaultFailsafeMinutes = 1440;
```

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze lib/constants.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/constants.dart
git commit -m "feat: add centralized Flutter constants file"
```

---

### Task 2: Replace Magic Strings in ProfileManager

**Files:**
- Modify: `lib/services/profile_manager.dart`

- [ ] **Step 1: Add import and replace raw strings**

Add import at top of `lib/services/profile_manager.dart`:

```dart
import '../constants.dart';
```

Replace on line 35:
```dart
// old:
    final savedProfiles = _prefs.getString('savedProfiles');
// new:
    final savedProfiles = _prefs.getString(kPrefSavedProfiles);
```

Replace on line 45:
```dart
// old:
    final savedId = _prefs.getString('currentProfileId');
// new:
    final savedId = _prefs.getString(kPrefCurrentProfileId);
```

Replace on line 56:
```dart
// old:
    await _prefs.setString('savedProfiles', Profile.encodeList(_profiles));
// new:
    await _prefs.setString(kPrefSavedProfiles, Profile.encodeList(_profiles));
```

Replace on line 58:
```dart
// old:
      await _prefs.setString('currentProfileId', _currentProfileId!);
// new:
      await _prefs.setString(kPrefCurrentProfileId, _currentProfileId!);
```

- [ ] **Step 2: Run tests**

Run: `flutter test test/services/profile_manager_test.dart`
Expected: All tests pass

- [ ] **Step 3: Commit**

```bash
git add lib/services/profile_manager.dart
git commit -m "refactor: use constants for SharedPreferences keys in ProfileManager"
```

---

### Task 3: Replace Magic Strings in AppBlockerService

**Files:**
- Modify: `lib/services/app_blocker_service.dart`

- [ ] **Step 1: Add import and replace raw strings**

Add import at top of `lib/services/app_blocker_service.dart`:

```dart
import '../constants.dart';
```

Replace on line 197:
```dart
// old:
    final locksJson = _prefs.getString('activeLocks');
// new:
    final locksJson = _prefs.getString(kPrefActiveLocks);
```

Replace on line 215:
```dart
// old:
      final legacyBlocking = _prefs.getBool('isBlocking') ?? false;
// new:
      final legacyBlocking = _prefs.getBool(kPrefIsBlocking) ?? false;
```

Replace on line 218:
```dart
// old:
        await _prefs.setBool('isBlocking', false);
// new:
        await _prefs.setBool(kPrefIsBlocking, false);
```

Replace on line 227:
```dart
// old:
    await _prefs.setString('activeLocks', jsonEncode(list));
// new:
    await _prefs.setString(kPrefActiveLocks, jsonEncode(list));
```

Replace on line 229:
```dart
// old:
    await _prefs.setBool('isBlocking', _activeLocks.isNotEmpty);
// new:
    await _prefs.setBool(kPrefIsBlocking, _activeLocks.isNotEmpty);
```

- [ ] **Step 2: Run tests**

Run: `flutter test test/services/app_blocker_service_test.dart`
Expected: All tests pass

- [ ] **Step 3: Commit**

```bash
git add lib/services/app_blocker_service.dart
git commit -m "refactor: use constants for SharedPreferences keys in AppBlockerService"
```

---

### Task 4: Replace Magic Strings in PlatformChannelService

**Files:**
- Modify: `lib/services/platform_channel_service.dart`

- [ ] **Step 1: Add import and replace channel name**

Add import at top of `lib/services/platform_channel_service.dart`:

```dart
import '../constants.dart';
```

Replace on line 28:
```dart
// old:
  static const _channel = MethodChannel('com.example.phone_lockdown/blocker');
// new:
  static const _channel = MethodChannel(kMethodChannel);
```

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze lib/services/platform_channel_service.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/services/platform_channel_service.dart
git commit -m "refactor: use constant for method channel name in PlatformChannelService"
```

---

### Task 5: Replace Default Failsafe in Profile Model

**Files:**
- Modify: `lib/models/profile.dart`

- [ ] **Step 1: Add import and replace defaults**

Add import at top of `lib/models/profile.dart`:

```dart
import '../constants.dart';
```

Replace on line 22:
```dart
// old:
    this.failsafeMinutes = 1440,
// new:
    this.failsafeMinutes = kDefaultFailsafeMinutes,
```

Replace on line 49:
```dart
// old:
      failsafeMinutes: (json['failsafeMinutes'] as int?) ?? 1440,
// new:
      failsafeMinutes: (json['failsafeMinutes'] as int?) ?? kDefaultFailsafeMinutes,
```

- [ ] **Step 2: Run tests**

Run: `flutter test test/services/profile_manager_test.dart`
Expected: All tests pass (the test on line 61 expects 1440, which is still the value of `kDefaultFailsafeMinutes`)

- [ ] **Step 3: Commit**

```bash
git add lib/models/profile.dart
git commit -m "refactor: use kDefaultFailsafeMinutes constant in Profile model"
```

---

### Task 6: Decompose ProfileFormDialog — Create Icon Picker

**Files:**
- Create: `lib/widgets/profile_form/icon_picker.dart`

- [ ] **Step 1: Create the directory and icon_picker.dart**

```bash
mkdir -p lib/widgets/profile_form
```

Create `lib/widgets/profile_form/icon_picker.dart`:

```dart
import 'package:flutter/material.dart';

class IconPicker extends StatelessWidget {
  final int selectedIconCodePoint;
  final ValueChanged<int> onIconSelected;

  const IconPicker({
    super.key,
    required this.selectedIconCodePoint,
    required this.onIconSelected,
  });

  static const iconOptions = [
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
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose Icon', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: iconOptions.map((icon) {
            final isSelected = icon.codePoint == selectedIconCodePoint;
            return GestureDetector(
              onTap: () => onIconSelected(icon.codePoint),
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
      ],
    );
  }
}
```

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze lib/widgets/profile_form/icon_picker.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/profile_form/icon_picker.dart
git commit -m "feat: extract IconPicker sub-widget from ProfileFormDialog"
```

---

### Task 7: Decompose ProfileFormDialog — Create Unlock Code Section

**Files:**
- Create: `lib/widgets/profile_form/unlock_code_section.dart`

- [ ] **Step 1: Create unlock_code_section.dart**

```dart
import 'package:flutter/material.dart';

class UnlockCodeSection extends StatelessWidget {
  final String? unlockCode;
  final VoidCallback onScan;
  final VoidCallback onClear;

  const UnlockCodeSection({
    super.key,
    required this.unlockCode,
    required this.onScan,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Unlock Code', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Icon(
                unlockCode != null ? Icons.vpn_key : Icons.vpn_key_off,
                size: 20,
                color: unlockCode != null ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  unlockCode != null
                      ? '${unlockCode!.substring(0, unlockCode!.length.clamp(0, 12))}...'
                      : 'No code set',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: unlockCode != null ? Colors.white : Colors.grey,
                  ),
                ),
              ),
              if (unlockCode != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onClear,
                  tooltip: 'Clear code',
                ),
              IconButton(
                icon: const Icon(Icons.qr_code_scanner, size: 20),
                onPressed: onScan,
                tooltip: 'Scan code',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze lib/widgets/profile_form/unlock_code_section.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/profile_form/unlock_code_section.dart
git commit -m "feat: extract UnlockCodeSection sub-widget from ProfileFormDialog"
```

---

### Task 8: Decompose ProfileFormDialog — Create App Selector

**Files:**
- Create: `lib/widgets/profile_form/app_selector.dart`

- [ ] **Step 1: Create app_selector.dart**

```dart
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
```

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze lib/widgets/profile_form/app_selector.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/profile_form/app_selector.dart
git commit -m "feat: extract AppSelector sub-widget from ProfileFormDialog"
```

---

### Task 9: Decompose ProfileFormDialog — Create Website Editor

**Files:**
- Create: `lib/widgets/profile_form/website_editor.dart`

- [ ] **Step 1: Create website_editor.dart**

```dart
import 'package:flutter/material.dart';

class WebsiteEditor extends StatefulWidget {
  final List<String> blockedWebsites;
  final ValueChanged<List<String>> onChanged;

  const WebsiteEditor({
    super.key,
    required this.blockedWebsites,
    required this.onChanged,
  });

  @override
  State<WebsiteEditor> createState() => _WebsiteEditorState();
}

class _WebsiteEditorState extends State<WebsiteEditor> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addWebsite() {
    final website = _controller.text.trim().toLowerCase();
    if (website.isEmpty || !website.contains('.')) return;
    if (widget.blockedWebsites.contains(website)) return;

    widget.onChanged([...widget.blockedWebsites, website]);
    _controller.clear();
  }

  void _removeWebsite(String website) {
    widget.onChanged(
      widget.blockedWebsites.where((w) => w != website).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Blocked Websites',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'e.g. youtube.com',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _addWebsite(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle),
              onPressed: _addWebsite,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...widget.blockedWebsites.map((website) => ListTile(
              dense: true,
              title: Text(website),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => _removeWebsite(website),
              ),
            )),
      ],
    );
  }
}
```

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze lib/widgets/profile_form/website_editor.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/profile_form/website_editor.dart
git commit -m "feat: extract WebsiteEditor sub-widget from ProfileFormDialog"
```

---

### Task 10: Decompose ProfileFormDialog — Create Failsafe Selector

**Files:**
- Create: `lib/widgets/profile_form/failsafe_selector.dart`

- [ ] **Step 1: Create failsafe_selector.dart**

```dart
import 'package:flutter/material.dart';

class FailsafeSelector extends StatelessWidget {
  final int failsafeMinutes;
  final ValueChanged<int> onChanged;

  const FailsafeSelector({
    super.key,
    required this.failsafeMinutes,
    required this.onChanged,
  });

  static const presets = [
    (minutes: 15, label: '15 min'),
    (minutes: 30, label: '30 min'),
    (minutes: 60, label: '1 hour'),
    (minutes: 120, label: '2 hours'),
    (minutes: 240, label: '4 hours'),
    (minutes: 480, label: '8 hours'),
    (minutes: 720, label: '12 hours'),
    (minutes: 1440, label: '24 hours'),
  ];

  static String formatFailsafe(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    if (remaining == 0) return hours == 1 ? '1 hour' : '$hours hours';
    return '${hours}h ${remaining}m';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Failsafe Auto-Unlock',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          'Automatically unlocks after this duration, even without scanning the code.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
                fontSize: 12,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets.map((preset) {
            final isSelected = failsafeMinutes == preset.minutes;
            return ChoiceChip(
              label: Text(preset.label),
              selected: isSelected,
              onSelected: (_) => onChanged(preset.minutes),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text(
          'Current: ${formatFailsafe(failsafeMinutes)}',
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze lib/widgets/profile_form/failsafe_selector.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/profile_form/failsafe_selector.dart
git commit -m "feat: extract FailsafeSelector sub-widget from ProfileFormDialog"
```

---

### Task 11: Rewrite ProfileFormDialog as Compositor

**Files:**
- Create: `lib/widgets/profile_form/profile_form_dialog.dart`
- Delete: `lib/widgets/profile_form_dialog.dart`
- Modify: `lib/widgets/profile_picker.dart`

- [ ] **Step 1: Create the new compositor at `lib/widgets/profile_form/profile_form_dialog.dart`**

```dart
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
```

- [ ] **Step 2: Update import in `lib/widgets/profile_picker.dart`**

Replace line 6:
```dart
// old:
import 'profile_form_dialog.dart';
// new:
import 'profile_form/profile_form_dialog.dart';
```

- [ ] **Step 3: Delete the old file**

```bash
rm lib/widgets/profile_form_dialog.dart
```

- [ ] **Step 4: Run analyzer**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/profile_form/ lib/widgets/profile_picker.dart
git rm lib/widgets/profile_form_dialog.dart
git commit -m "refactor: decompose ProfileFormDialog into focused sub-widgets"
```

---

### Task 12: Create Android Constants File

**Files:**
- Create: `android/app/src/main/kotlin/com/example/phone_lockdown/Constants.kt`

Note: This file is created in the old package path for now. Task 15 will move it along with all other Kotlin files.

- [ ] **Step 1: Create `Constants.kt`**

```kotlin
package com.example.phone_lockdown

object Constants {
    // SharedPreferences keys
    const val PREF_IS_BLOCKING = "isBlocking"
    const val PREF_BLOCKED_PACKAGES = "blockedPackages"
    const val PREF_BLOCKED_WEBSITES = "blockedWebsites"
    const val PREF_ACTIVE_PROFILE_BLOCKS = "activeProfileBlocks"
    const val PREF_FAILSAFE_ALARMS = "failsafeAlarms"

    // Method channel
    const val METHOD_CHANNEL = "app.phonelockdown/blocker"
}
```

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/kotlin/com/example/phone_lockdown/Constants.kt
git commit -m "feat: add centralized Android Constants object"
```

---

### Task 13: Replace Magic Strings in Android — BlockingStateManager and MainActivity

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/phone_lockdown/BlockingStateManager.kt`
- Modify: `android/app/src/main/kotlin/com/example/phone_lockdown/MainActivity.kt`

- [ ] **Step 1: Replace strings in BlockingStateManager.kt**

Replace line 28:
```kotlin
// old:
            .putBoolean("isBlocking", isBlocking)
// new:
            .putBoolean(Constants.PREF_IS_BLOCKING, isBlocking)
```

Replace line 29:
```kotlin
// old:
            .putStringSet("blockedPackages", packages.toSet())
// new:
            .putStringSet(Constants.PREF_BLOCKED_PACKAGES, packages.toSet())
```

Replace line 30:
```kotlin
// old:
            .putStringSet("blockedWebsites", websites.toSet())
// new:
            .putStringSet(Constants.PREF_BLOCKED_WEBSITES, websites.toSet())
```

Replace line 51:
```kotlin
// old:
            editor.putString("activeProfileBlocks", jsonArray.toString())
// new:
            editor.putString(Constants.PREF_ACTIVE_PROFILE_BLOCKS, jsonArray.toString())
```

Replace line 72:
```kotlin
// old:
        val isBlocking = prefs.getBoolean("isBlocking", false)
// new:
        val isBlocking = prefs.getBoolean(Constants.PREF_IS_BLOCKING, false)
```

Replace line 73:
```kotlin
// old:
        val blocksJson = prefs.getString("activeProfileBlocks", "[]")
// new:
        val blocksJson = prefs.getString(Constants.PREF_ACTIVE_PROFILE_BLOCKS, "[]")
```

Replace line 99:
```kotlin
// old:
        val alarmsJson = prefs.getString("failsafeAlarms", "[]")
// new:
        val alarmsJson = prefs.getString(Constants.PREF_FAILSAFE_ALARMS, "[]")
```

Replace line 112:
```kotlin
// old:
        prefs.edit().putString("failsafeAlarms", updatedAlarms.toString()).apply()
// new:
        prefs.edit().putString(Constants.PREF_FAILSAFE_ALARMS, updatedAlarms.toString()).apply()
```

Replace line 135:
```kotlin
// old:
        val alarmsJson = prefs.getString("failsafeAlarms", "[]")
// new:
        val alarmsJson = prefs.getString(Constants.PREF_FAILSAFE_ALARMS, "[]")
```

Replace line 144:
```kotlin
// old:
        prefs.edit().putString("failsafeAlarms", updatedAlarms.toString()).apply()
// new:
        prefs.edit().putString(Constants.PREF_FAILSAFE_ALARMS, updatedAlarms.toString()).apply()
```

- [ ] **Step 2: Replace channel name in MainActivity.kt**

Replace line 13:
```kotlin
// old:
    private val channelName = "com.example.phone_lockdown/blocker"
// new:
    private val channelName = Constants.METHOD_CHANNEL
```

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/example/phone_lockdown/BlockingStateManager.kt
git add android/app/src/main/kotlin/com/example/phone_lockdown/MainActivity.kt
git commit -m "refactor: use Constants for pref keys and channel name in BlockingStateManager and MainActivity"
```

---

### Task 14: Replace Magic Strings in Android — FailsafeAlarmReceiver, LockdownAccessibilityService, LockdownVpnService, ServiceMonitorWorker

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/phone_lockdown/FailsafeAlarmReceiver.kt`
- Modify: `android/app/src/main/kotlin/com/example/phone_lockdown/LockdownAccessibilityService.kt`
- Modify: `android/app/src/main/kotlin/com/example/phone_lockdown/LockdownVpnService.kt`
- Modify: `android/app/src/main/kotlin/com/example/phone_lockdown/ServiceMonitorWorker.kt`

- [ ] **Step 1: Replace strings in FailsafeAlarmReceiver.kt**

Replace line 29:
```kotlin
// old:
            val alarmsJson = prefs.getString("failsafeAlarms", "[]")
// new:
            val alarmsJson = prefs.getString(Constants.PREF_FAILSAFE_ALARMS, "[]")
```

Replace line 40:
```kotlin
// old:
            val blocksJson = prefs.getString("activeProfileBlocks", "[]")
// new:
            val blocksJson = prefs.getString(Constants.PREF_ACTIVE_PROFILE_BLOCKS, "[]")
```

Replace line 64:
```kotlin
// old:
                .putBoolean("isBlocking", hasRemainingProfiles)
// new:
                .putBoolean(Constants.PREF_IS_BLOCKING, hasRemainingProfiles)
```

Replace line 65:
```kotlin
// old:
                .putStringSet("blockedPackages", if (hasRemainingProfiles) mergedPackages else emptySet())
// new:
                .putStringSet(Constants.PREF_BLOCKED_PACKAGES, if (hasRemainingProfiles) mergedPackages else emptySet())
```

Replace line 66:
```kotlin
// old:
                .putStringSet("blockedWebsites", if (hasRemainingProfiles) mergedWebsites else emptySet())
// new:
                .putStringSet(Constants.PREF_BLOCKED_WEBSITES, if (hasRemainingProfiles) mergedWebsites else emptySet())
```

Replace line 67:
```kotlin
// old:
                .putString("activeProfileBlocks", updatedBlocks.toString())
// new:
                .putString(Constants.PREF_ACTIVE_PROFILE_BLOCKS, updatedBlocks.toString())
```

Replace line 68:
```kotlin
// old:
                .putString("failsafeAlarms", updatedAlarms.toString())
// new:
                .putString(Constants.PREF_FAILSAFE_ALARMS, updatedAlarms.toString())
```

- [ ] **Step 2: Replace strings in LockdownAccessibilityService.kt**

Replace line 89:
```kotlin
// old:
        setBlockingActiveSilently(prefs.getBoolean("isBlocking", false))
// new:
        setBlockingActiveSilently(prefs.getBoolean(Constants.PREF_IS_BLOCKING, false))
```

Replace line 90:
```kotlin
// old:
        blockedPackages = prefs.getStringSet("blockedPackages", emptySet()) ?: emptySet()
// new:
        blockedPackages = prefs.getStringSet(Constants.PREF_BLOCKED_PACKAGES, emptySet()) ?: emptySet()
```

Replace line 91:
```kotlin
// old:
        blockedWebsites = prefs.getStringSet("blockedWebsites", emptySet()) ?: emptySet()
// new:
        blockedWebsites = prefs.getStringSet(Constants.PREF_BLOCKED_WEBSITES, emptySet()) ?: emptySet()
```

- [ ] **Step 3: Replace strings in LockdownVpnService.kt**

Replace line 325:
```kotlin
// old:
        blockedWebsites = prefs.getStringSet("blockedWebsites", emptySet()) ?: emptySet()
// new:
        blockedWebsites = prefs.getStringSet(Constants.PREF_BLOCKED_WEBSITES, emptySet()) ?: emptySet()
```

- [ ] **Step 4: Replace strings in ServiceMonitorWorker.kt**

Replace line 27:
```kotlin
// old:
        val isBlocking = prefs.getBoolean("isBlocking", false)
// new:
        val isBlocking = prefs.getBoolean(Constants.PREF_IS_BLOCKING, false)
```

Replace line 35:
```kotlin
// old:
        if (!prefs.getBoolean("isBlocking", false)) return Result.success()
// new:
        if (!prefs.getBoolean(Constants.PREF_IS_BLOCKING, false)) return Result.success()
```

Replace line 46:
```kotlin
// old:
        val blockedWebsites = prefs.getStringSet("blockedWebsites", emptySet()) ?: emptySet()
// new:
        val blockedWebsites = prefs.getStringSet(Constants.PREF_BLOCKED_WEBSITES, emptySet()) ?: emptySet()
```

Replace line 68:
```kotlin
// old:
            val alarmsJson = prefs.getString("failsafeAlarms", "[]") ?: "[]"
// new:
            val alarmsJson = prefs.getString(Constants.PREF_FAILSAFE_ALARMS, "[]") ?: "[]"
```

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/example/phone_lockdown/FailsafeAlarmReceiver.kt
git add android/app/src/main/kotlin/com/example/phone_lockdown/LockdownAccessibilityService.kt
git add android/app/src/main/kotlin/com/example/phone_lockdown/LockdownVpnService.kt
git add android/app/src/main/kotlin/com/example/phone_lockdown/ServiceMonitorWorker.kt
git commit -m "refactor: use Constants for pref keys in remaining Android files"
```

---

### Task 15: Rename Package — Move Kotlin Files and Update Declarations

**Files:**
- Modify: `android/app/build.gradle.kts`
- Move: all files from `android/app/src/main/kotlin/com/example/phone_lockdown/` to `android/app/src/main/kotlin/app/phonelockdown/`
- Move: all files from `android/app/src/test/kotlin/com/example/phone_lockdown/` to `android/app/src/test/kotlin/app/phonelockdown/`
- Modify: all Kotlin source files (package declarations)

- [ ] **Step 1: Update build.gradle.kts**

Replace line 9 in `android/app/build.gradle.kts`:
```kotlin
// old:
    namespace = "com.example.phone_lockdown"
// new:
    namespace = "app.phonelockdown"
```

Replace line 24:
```kotlin
// old:
        applicationId = "com.example.phone_lockdown"
// new:
        applicationId = "app.phonelockdown"
```

Remove the TODO comment on line 23:
```kotlin
// old:
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.phonelockdown"
// new:
        applicationId = "app.phonelockdown"
```

- [ ] **Step 2: Move main source files to new directory structure**

```bash
mkdir -p android/app/src/main/kotlin/app/phonelockdown
mv android/app/src/main/kotlin/com/example/phone_lockdown/*.kt android/app/src/main/kotlin/app/phonelockdown/
rm -rf android/app/src/main/kotlin/com
```

- [ ] **Step 3: Move test source files to new directory structure**

```bash
mkdir -p android/app/src/test/kotlin/app/phonelockdown
mv android/app/src/test/kotlin/com/example/phone_lockdown/*.kt android/app/src/test/kotlin/app/phonelockdown/
rm -rf android/app/src/test/kotlin/com
```

- [ ] **Step 4: Update package declarations in all main Kotlin files**

Run find-and-replace in every `.kt` file under `android/app/src/main/kotlin/app/phonelockdown/`:

Replace `package com.example.phone_lockdown` with `package app.phonelockdown` in these files:
- `MainActivity.kt`
- `MethodChannelHandler.kt`
- `VpnController.kt`
- `LockdownVpnService.kt`
- `LockdownAccessibilityService.kt`
- `LockdownDeviceAdmin.kt`
- `BlockingStateManager.kt`
- `FailsafeAlarmReceiver.kt`
- `ServiceMonitorWorker.kt`
- `PermissionManager.kt`
- `AppListHelper.kt`
- `PrefsHelper.kt`
- `DnsPacketParser.kt`
- `DomainMatcher.kt`
- `Constants.kt`

Each file's first line changes from:
```kotlin
package com.example.phone_lockdown
```
to:
```kotlin
package app.phonelockdown
```

- [ ] **Step 5: Update package declarations in test Kotlin files**

Replace `package com.example.phone_lockdown` with `package app.phonelockdown` in:
- `DnsPacketParserTest.kt`
- `DomainMatcherTest.kt`

- [ ] **Step 6: Commit**

```bash
git add -A android/
git commit -m "refactor: rename package from com.example.phone_lockdown to app.phonelockdown"
```

---

### Task 16: Validate Full Build

- [ ] **Step 1: Run Flutter analyzer**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 2: Run Flutter tests**

Run: `flutter test`
Expected: All tests pass

- [ ] **Step 3: Run Android build**

Run: `cd android && ./gradlew build`
Expected: BUILD SUCCESSFUL

- [ ] **Step 4: Run Android unit tests**

Run: `cd android && ./gradlew test`
Expected: All tests pass

- [ ] **Step 5: Install on device (if connected)**

Run: `adb devices` to check. If a device is connected:

Run: `cd android && ./gradlew installDebug`
Expected: App installs and launches

- [ ] **Step 6: Push to GitHub**

```bash
git push origin main
```
