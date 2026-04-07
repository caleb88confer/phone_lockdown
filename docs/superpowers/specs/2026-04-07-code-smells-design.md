# Code Smells Cleanup Design

Date: 2026-04-07

## Overview

Three targeted refactors to improve code quality: decompose an oversized widget, centralize magic strings/numbers, and rename the package from the example namespace.

## 1. ProfileFormDialog Decomposition

### Problem

`lib/widgets/profile_form_dialog.dart` is 417 lines handling icon picking, app selection, website editing, QR scanning, failsafe configuration, and form validation in a single widget.

### Solution

Replace with a directory of focused sub-widgets:

```
lib/widgets/profile_form/
├── profile_form_dialog.dart    # Compositor — owns form state, composes sub-widgets
├── icon_picker.dart            # Grid of icon options, returns selected IconData
├── unlock_code_section.dart    # Code display, scan button, clear button
├── app_selector.dart           # Shows selected app count, navigates to AppPickerScreen
├── website_editor.dart         # Website list + add input with validation
└── failsafe_selector.dart      # ChoiceChips for failsafe duration presets
```

### State Ownership

`ProfileFormDialog` remains the single stateful widget holding all form state: `_name`, `_icon`, `_blockedApps`, `_blockedWebsites`, `_unlockCode`, `_failsafeMinutes`. Sub-widgets receive current values and callbacks (standard "lift state up" pattern). No new state management libraries.

### Import Updates

Existing imports of `widgets/profile_form_dialog.dart` update to `widgets/profile_form/profile_form_dialog.dart`.

## 2. Constants Centralization

### Problem

Magic strings and numbers are scattered across files:
- Method channel name `"com.example.phone_lockdown/blocker"` in `platform_channel_service.dart:28` and `MainActivity.kt:13`
- SharedPreferences keys (`"savedProfiles"`, `"activeLocks"`, `"currentProfileId"`, `"isBlocking"`, `"blockedPackages"`, `"blockedWebsites"`, `"activeProfileBlocks"`, `"failsafeAlarms"`) as raw strings in `profile_manager.dart`, `app_blocker_service.dart`, `BlockingStateManager.kt`, `FailsafeAlarmReceiver.kt`
- Default failsafe of 1440 minutes in `profile.dart:22`, `profile.dart:49`, `profile_form_dialog.dart:78`

### Solution

**Flutter** — new file `lib/constants.dart`:

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

**Android** — new file `Constants.kt` in package root:

```kotlin
object Constants {
    const val PREF_IS_BLOCKING = "isBlocking"
    const val PREF_BLOCKED_PACKAGES = "blockedPackages"
    const val PREF_BLOCKED_WEBSITES = "blockedWebsites"
    const val PREF_ACTIVE_PROFILE_BLOCKS = "activeProfileBlocks"
    const val PREF_FAILSAFE_ALARMS = "failsafeAlarms"
    const val METHOD_CHANNEL = "app.phonelockdown/blocker"
}
```

All raw string usages in `ProfileManager`, `AppBlockerService`, `BlockingStateManager`, `FailsafeAlarmReceiver`, `MainActivity`, and `PlatformChannelService` get replaced with constant references.

### DNS Constants Stay Put

`DNS_SERVER`, `DNS_SERVER_SECONDARY`, and `DNS_SERVERS` remain in `LockdownVpnService.kt`'s companion object — they are already named constants and only used within that file.

## 3. Package Rename

### Problem

The app uses `com.example.phone_lockdown` — the default example namespace. This will conflict on the Play Store and with other `com.example.*` apps.

### New Package Name

`app.phonelockdown`

### Changes Required

**Build config** (`android/app/build.gradle.kts`):
- `namespace` → `"app.phonelockdown"`
- `applicationId` → `"app.phonelockdown"`

**Directory structure:**
- Move `android/app/src/main/kotlin/com/example/phone_lockdown/` → `android/app/src/main/kotlin/app/phonelockdown/`
- Move `android/app/src/test/kotlin/com/example/phone_lockdown/` → `android/app/src/test/kotlin/app/phonelockdown/`
- Remove empty `com/example/phone_lockdown/` directories

**Code changes:**
- All `package com.example.phone_lockdown` → `package app.phonelockdown`
- All `import com.example.phone_lockdown.*` → `import app.phonelockdown.*`
- Method channel name handled by constants (section 2)

**AndroidManifest.xml:** No changes needed — activity/service/receiver references use relative names (`.MainActivity`, etc.) which resolve against the namespace.

### Breaking Change

This is a clean break for existing installs — Android treats a different applicationId as a different app. Acceptable since the app has not been published to the Play Store.

## Validation

1. `flutter analyze` — no warnings or errors
2. `flutter test` — all existing tests pass
3. `cd android && ./gradlew build` — Android compiles cleanly
4. Install on device — verify profiles can be created, edited, activated, and deactivated
