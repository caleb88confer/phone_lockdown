# Phone Lockdown

A Flutter app for Android that helps you control phone usage by blocking apps with NFC-based toggling.

## Features

### NFC Tag System
- Scan NFC tags to toggle app blocking on and off
- Create custom NFC tags by writing a validation phrase to blank tags
- Tags are validated before toggling to prevent accidental activation

### Profile Management
- Create multiple blocking profiles, each with its own set of blocked apps
- Default profile included out of the box
- Choose from 20 different icons to personalize each profile
- Long-press a profile to edit or delete it

### App Blocking
- Tap the lock button to toggle blocking on or off
- Visual feedback with animated color transitions (red when blocking, green when not)
- Blocking state persists across app restarts
- Profile picker is hidden while blocking is active to prevent changes

## Current Limitations

- **App blocking is stubbed** — the UI and state management work, but actual enforcement via Android AccessibilityService is not yet implemented
- **App picker is a placeholder** — the "Configure Blocked Apps" button in profile editing does not yet list installed apps
- Android only (no iOS support)

## Getting Started

```bash
flutter pub get
flutter run
```

Requires an Android device or emulator. NFC features require a device with NFC hardware.
