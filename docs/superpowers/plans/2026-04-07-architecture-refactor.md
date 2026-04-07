# Architecture Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Decompose the God Activity, fix dual state persistence with ownership split, and add dependency injection for testability.

**Architecture:** Flutter DI first (safest, pure refactor), then Android decomposition (extract classes), then reconciliation (the only behavior change). Each phase leaves the app fully functional.

**Tech Stack:** Flutter/Dart (Provider, SharedPreferences), Kotlin (EncryptedSharedPreferences, MethodChannel)

---

## Task 1: Extract PlatformChannelService Interface

**Files:**
- Modify: `lib/services/platform_channel_service.dart` (full rewrite)

- [ ] **Step 1: Rewrite platform_channel_service.dart as abstract interface + concrete implementation**

Replace the entire file with:

```dart
import 'package:flutter/services.dart';

abstract class PlatformChannelService {
  Future<List<Map<String, dynamic>>> getInstalledApps();
  Future<Map<String, bool>> checkPermissions();
  Future<void> updateBlockingState({
    required bool isBlocking,
    required List<String> blockedPackages,
    required List<String> blockedWebsites,
    List<Map<String, dynamic>>? activeProfileBlocks,
  });
  Future<void> scheduleFailsafeAlarm({
    required String profileId,
    required int failsafeMillis,
  });
  Future<void> cancelFailsafeAlarm({required String profileId});
  Future<void> openAccessibilitySettings();
  Future<void> openUsageStatsSettings();
  Future<void> requestDeviceAdmin();
  Future<bool> prepareVpn();
  Future<void> startVpn();
  Future<void> stopVpn();
  Future<bool> isVpnActive();
}

class MethodChannelPlatformService implements PlatformChannelService {
  static const _channel = MethodChannel('com.example.phone_lockdown/blocker');

  @override
  Future<List<Map<String, dynamic>>> getInstalledApps() async {
    final List<dynamic> result = await _channel.invokeMethod('getInstalledApps');
    return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<Map<String, bool>> checkPermissions() async {
    final Map<dynamic, dynamic> result =
        await _channel.invokeMethod('checkPermissions');
    return result.map((k, v) => MapEntry(k as String, v as bool));
  }

  @override
  Future<void> updateBlockingState({
    required bool isBlocking,
    required List<String> blockedPackages,
    required List<String> blockedWebsites,
    List<Map<String, dynamic>>? activeProfileBlocks,
  }) async {
    await _channel.invokeMethod('updateBlockingState', {
      'isBlocking': isBlocking,
      'blockedPackages': blockedPackages,
      'blockedWebsites': blockedWebsites,
      'activeProfileBlocks': activeProfileBlocks ?? [],
    });
  }

  @override
  Future<void> scheduleFailsafeAlarm({
    required String profileId,
    required int failsafeMillis,
  }) async {
    await _channel.invokeMethod('scheduleFailsafeAlarm', {
      'profileId': profileId,
      'failsafeMillis': failsafeMillis,
    });
  }

  @override
  Future<void> cancelFailsafeAlarm({required String profileId}) async {
    await _channel.invokeMethod('cancelFailsafeAlarm', {
      'profileId': profileId,
    });
  }

  @override
  Future<void> openAccessibilitySettings() async {
    await _channel.invokeMethod('openAccessibilitySettings');
  }

  @override
  Future<void> openUsageStatsSettings() async {
    await _channel.invokeMethod('openUsageStatsSettings');
  }

  @override
  Future<void> requestDeviceAdmin() async {
    await _channel.invokeMethod('requestDeviceAdmin');
  }

  @override
  Future<bool> prepareVpn() async {
    final result = await _channel.invokeMethod<bool>('prepareVpn');
    return result ?? false;
  }

  @override
  Future<void> startVpn() async {
    await _channel.invokeMethod('startVpn');
  }

  @override
  Future<void> stopVpn() async {
    await _channel.invokeMethod('stopVpn');
  }

  @override
  Future<bool> isVpnActive() async {
    final result = await _channel.invokeMethod<bool>('isVpnActive');
    return result ?? false;
  }
}
```

- [ ] **Step 2: Run Flutter analyze to verify no syntax errors**

Run: `cd /Users/calebconfer/Desktop/Projects/phone_lockdown && flutter analyze lib/services/platform_channel_service.dart`
Expected: No errors (warnings about unused imports from other files are OK at this point)

- [ ] **Step 3: Commit**

```bash
git add lib/services/platform_channel_service.dart
git commit -m "refactor: extract PlatformChannelService abstract interface"
```

---

## Task 2: Inject Dependencies into AppBlockerService

**Files:**
- Modify: `lib/services/app_blocker_service.dart`
- Modify: `test/services/app_blocker_service_test.dart`

- [ ] **Step 1: Modify AppBlockerService to accept injected dependencies**

In `lib/services/app_blocker_service.dart`, replace the constructor and add fields. Change:

```dart
import 'platform_channel_service.dart';
```
(keep this import, it's now the abstract class)

Replace the class fields and constructor (lines 45-62):

```dart
class AppBlockerService extends ChangeNotifier {
  final PlatformChannelService _platform;
  final SharedPreferences _prefs;
  final Map<String, ActiveLock> _activeLocks = {};
  bool _isAccessibilityEnabled = false;
  bool _isDeviceAdminEnabled = false;
  bool _isVpnPrepared = false;

  bool get isBlocking => _activeLocks.isNotEmpty;
  Set<String> get activeProfileIds => _activeLocks.keys.toSet();
  bool get isAccessibilityEnabled => _isAccessibilityEnabled;
  bool get isDeviceAdminEnabled => _isDeviceAdminEnabled;
  bool get isVpnPrepared => _isVpnPrepared;

  ActiveLock? getLock(String profileId) => _activeLocks[profileId];

  AppBlockerService({
    required PlatformChannelService platform,
    required SharedPreferences prefs,
  })  : _platform = platform,
        _prefs = prefs {
    _loadBlockingState();
    refreshPermissions();
  }
```

Replace `refreshPermissions()` (lines 64-74) to use `_platform`:

```dart
  Future<void> refreshPermissions() async {
    try {
      final permissions = await _platform.checkPermissions();
      _isAccessibilityEnabled = permissions['accessibility'] ?? false;
      _isDeviceAdminEnabled = permissions['deviceAdmin'] ?? false;
      _isVpnPrepared = permissions['vpn'] ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to check permissions: $e');
    }
  }
```

Replace `activateProfile()` (lines 76-106) to use `_platform`:

```dart
  Future<bool> activateProfile(Profile profile, {required List<Profile> allProfiles}) async {
    if (!_isAccessibilityEnabled) {
      debugPrint('Accessibility service not enabled');
      return false;
    }

    final lock = ActiveLock(
      profileId: profile.id,
      lockStartTime: DateTime.now(),
      failsafeMinutes: profile.failsafeMinutes,
    );

    _activeLocks[profile.id] = lock;
    _startFailsafeTimer(lock, allProfiles);

    await _saveActiveLocks();
    await _recomputeAndApply(allProfiles);

    try {
      await _platform.scheduleFailsafeAlarm(
        profileId: profile.id,
        failsafeMillis: lock.remaining.inMilliseconds,
      );
    } catch (e) {
      debugPrint('Failed to schedule failsafe alarm: $e');
    }

    notifyListeners();
    return true;
  }
```

Replace `deactivateProfile()` (lines 108-126) to use `_platform`:

```dart
  Future<bool> deactivateProfile(String profileId, {required List<Profile> allProfiles}) async {
    final lock = _activeLocks.remove(profileId);
    if (lock == null) return false;

    lock.timer?.cancel();

    await _saveActiveLocks();
    await _recomputeAndApply(allProfiles);

    try {
      await _platform.cancelFailsafeAlarm(profileId: profileId);
    } catch (e) {
      debugPrint('Failed to cancel failsafe alarm: $e');
    }

    notifyListeners();
    return true;
  }
```

Replace `_recomputeAndApply()` (lines 141-186) to use `_platform`:

```dart
  Future<void> _recomputeAndApply(List<Profile> allProfiles) async {
    if (_activeLocks.isEmpty) {
      try {
        await _platform.updateBlockingState(
          isBlocking: false,
          blockedPackages: [],
          blockedWebsites: [],
          activeProfileBlocks: [],
        );
      } catch (e) {
        debugPrint('Failed to update blocking state: $e');
      }
      return;
    }

    final mergedPackages = <String>{};
    final mergedWebsites = <String>{};
    final profileBlocks = <Map<String, dynamic>>[];

    for (final lockEntry in _activeLocks.values) {
      final profile = allProfiles.cast<Profile?>().firstWhere(
            (p) => p!.id == lockEntry.profileId,
            orElse: () => null,
          );
      if (profile != null) {
        mergedPackages.addAll(profile.blockedAppPackages);
        mergedWebsites.addAll(profile.blockedWebsites);
        profileBlocks.add({
          'profileId': profile.id,
          'blockedPackages': profile.blockedAppPackages,
          'blockedWebsites': profile.blockedWebsites,
        });
      }
    }

    try {
      await _platform.updateBlockingState(
        isBlocking: true,
        blockedPackages: mergedPackages.toList(),
        blockedWebsites: mergedWebsites.toList(),
        activeProfileBlocks: profileBlocks,
      );
    } catch (e) {
      debugPrint('Failed to update blocking state: $e');
    }
  }
```

Replace `_loadBlockingState()` (lines 188-216) to use `_prefs`:

```dart
  Future<void> _loadBlockingState() async {
    final locksJson = _prefs.getString('activeLocks');

    if (locksJson != null) {
      try {
        final list = jsonDecode(locksJson) as List;
        for (final item in list) {
          final lock = ActiveLock.fromJson(item as Map<String, dynamic>);
          if (!lock.isExpired) {
            _activeLocks[lock.profileId] = lock;
          }
        }
      } catch (e) {
        debugPrint('Failed to load active locks: $e');
      }
    }

    if (_activeLocks.isEmpty) {
      final legacyBlocking = _prefs.getBool('isBlocking') ?? false;
      if (legacyBlocking) {
        await _prefs.setBool('isBlocking', false);
      }
    }

    notifyListeners();
  }
```

Replace `_saveActiveLocks()` (lines 218-224) to use `_prefs`:

```dart
  Future<void> _saveActiveLocks() async {
    final list = _activeLocks.values.map((l) => l.toJson()).toList();
    await _prefs.setString('activeLocks', jsonEncode(list));
    await _prefs.setBool('isBlocking', _activeLocks.isNotEmpty);
  }
```

Replace `prepareVpn()` (lines 246-256) to use `_platform`:

```dart
  Future<bool> prepareVpn() async {
    try {
      final result = await _platform.prepareVpn();
      _isVpnPrepared = result;
      notifyListeners();
      return result;
    } catch (e) {
      debugPrint('Failed to prepare VPN: $e');
      return false;
    }
  }
```

Remove the `import 'package:shared_preferences/shared_preferences.dart';` line (no longer needed — prefs are injected).

- [ ] **Step 2: Create FakePlatformService test helper and update tests**

Replace the entire `test/services/app_blocker_service_test.dart`:

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phone_lockdown/models/profile.dart';
import 'package:phone_lockdown/services/app_blocker_service.dart';
import 'package:phone_lockdown/services/platform_channel_service.dart';

class FakePlatformService implements PlatformChannelService {
  final List<String> calls = [];
  Map<String, bool> permissionsResult = {
    'accessibility': true,
    'deviceAdmin': true,
    'vpn': true,
  };

  @override
  Future<Map<String, bool>> checkPermissions() async {
    calls.add('checkPermissions');
    return permissionsResult;
  }

  @override
  Future<void> updateBlockingState({
    required bool isBlocking,
    required List<String> blockedPackages,
    required List<String> blockedWebsites,
    List<Map<String, dynamic>>? activeProfileBlocks,
  }) async {
    calls.add('updateBlockingState(isBlocking=$isBlocking, '
        'packages=${blockedPackages.length}, '
        'websites=${blockedWebsites.length})');
  }

  @override
  Future<void> scheduleFailsafeAlarm({
    required String profileId,
    required int failsafeMillis,
  }) async {
    calls.add('scheduleFailsafeAlarm($profileId)');
  }

  @override
  Future<void> cancelFailsafeAlarm({required String profileId}) async {
    calls.add('cancelFailsafeAlarm($profileId)');
  }

  @override
  Future<List<Map<String, dynamic>>> getInstalledApps() async {
    calls.add('getInstalledApps');
    return [];
  }

  @override
  Future<void> openAccessibilitySettings() async {
    calls.add('openAccessibilitySettings');
  }

  @override
  Future<void> openUsageStatsSettings() async {
    calls.add('openUsageStatsSettings');
  }

  @override
  Future<void> requestDeviceAdmin() async {
    calls.add('requestDeviceAdmin');
  }

  @override
  Future<bool> prepareVpn() async {
    calls.add('prepareVpn');
    return true;
  }

  @override
  Future<void> startVpn() async {
    calls.add('startVpn');
  }

  @override
  Future<void> stopVpn() async {
    calls.add('stopVpn');
  }

  @override
  Future<bool> isVpnActive() async {
    calls.add('isVpnActive');
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakePlatformService fakePlatform;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    fakePlatform = FakePlatformService();
  });

  List<Profile> makeProfiles() {
    return [
      Profile(
        id: 'profile-1',
        name: 'Work',
        blockedAppPackages: ['com.twitter.android'],
        blockedWebsites: ['twitter.com'],
        failsafeMinutes: 60,
      ),
      Profile(
        id: 'profile-2',
        name: 'Study',
        blockedAppPackages: ['com.instagram.android'],
        blockedWebsites: ['instagram.com'],
        failsafeMinutes: 120,
      ),
    ];
  }

  AppBlockerService createService({SharedPreferences? overridePrefs}) {
    return AppBlockerService(
      platform: fakePlatform,
      prefs: overridePrefs ?? prefs,
    );
  }

  group('ActiveLock', () {
    test('toJson and fromJson are inverses', () {
      final lock = ActiveLock(
        profileId: 'test-id',
        lockStartTime: DateTime(2026, 1, 15, 10, 30),
        failsafeMinutes: 60,
      );

      final json = lock.toJson();
      final restored = ActiveLock.fromJson(json);

      expect(restored.profileId, 'test-id');
      expect(restored.lockStartTime, DateTime(2026, 1, 15, 10, 30));
      expect(restored.failsafeMinutes, 60);
    });

    test('isExpired returns true when time has passed', () {
      final lock = ActiveLock(
        profileId: 'test-id',
        lockStartTime: DateTime.now().subtract(const Duration(hours: 2)),
        failsafeMinutes: 60,
      );

      expect(lock.isExpired, isTrue);
      expect(lock.remaining, Duration.zero);
    });

    test('isExpired returns false when time remains', () {
      final lock = ActiveLock(
        profileId: 'test-id',
        lockStartTime: DateTime.now(),
        failsafeMinutes: 60,
      );

      expect(lock.isExpired, isFalse);
      expect(lock.remaining.inMinutes, greaterThan(0));
    });
  });

  group('AppBlockerService activation', () {
    test('activateProfile adds lock and reports blocking', () async {
      final service = createService();
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      final profiles = makeProfiles();
      final result = await service.activateProfile(
        profiles[0],
        allProfiles: profiles,
      );

      expect(result, isTrue);
      expect(service.isBlocking, isTrue);
      expect(service.activeProfileIds, contains('profile-1'));
      expect(fakePlatform.calls, contains('scheduleFailsafeAlarm(profile-1)'));
    });

    test('deactivateProfile removes lock', () async {
      final service = createService();
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      final profiles = makeProfiles();
      await service.activateProfile(profiles[0], allProfiles: profiles);
      final result = await service.deactivateProfile(
        'profile-1',
        allProfiles: profiles,
      );

      expect(result, isTrue);
      expect(service.isBlocking, isFalse);
      expect(service.activeProfileIds, isEmpty);
      expect(fakePlatform.calls, contains('cancelFailsafeAlarm(profile-1)'));
    });

    test('multiple profiles stack — blocking continues until all deactivated', () async {
      final service = createService();
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      final profiles = makeProfiles();
      await service.activateProfile(profiles[0], allProfiles: profiles);
      await service.activateProfile(profiles[1], allProfiles: profiles);

      expect(service.activeProfileIds.length, 2);

      await service.deactivateProfile('profile-1', allProfiles: profiles);
      expect(service.isBlocking, isTrue);

      await service.deactivateProfile('profile-2', allProfiles: profiles);
      expect(service.isBlocking, isFalse);
    });

    test('deactivateProfile returns false for non-existent profile', () async {
      final service = createService();
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      final profiles = makeProfiles();
      final result = await service.deactivateProfile(
        'non-existent',
        allProfiles: profiles,
      );

      expect(result, isFalse);
    });
  });

  group('AppBlockerService persistence', () {
    test('saves and restores active locks across instances', () async {
      final service1 = createService();
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      final profiles = makeProfiles();
      await service1.activateProfile(profiles[0], allProfiles: profiles);

      // Create a new service with the same prefs (simulates app restart)
      final fakePlatform2 = FakePlatformService();
      final service2 = AppBlockerService(platform: fakePlatform2, prefs: prefs);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      expect(service2.isBlocking, isTrue);
      expect(service2.activeProfileIds, contains('profile-1'));
    });

    test('restoreTimers removes expired locks', () async {
      SharedPreferences.setMockInitialValues({
        'activeLocks': jsonEncode([
          ActiveLock(
            profileId: 'expired-profile',
            lockStartTime: DateTime.now().subtract(const Duration(hours: 48)),
            failsafeMinutes: 60,
          ).toJson(),
        ]),
      });
      final expiredPrefs = await SharedPreferences.getInstance();

      final service = AppBlockerService(
        platform: fakePlatform,
        prefs: expiredPrefs,
      );
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      expect(service.isBlocking, isFalse);
    });
  });

  group('AppBlockerService platform calls', () {
    test('activateProfile calls updateBlockingState with merged packages', () async {
      final service = createService();
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      final profiles = makeProfiles();
      await service.activateProfile(profiles[0], allProfiles: profiles);

      expect(
        fakePlatform.calls,
        contains('updateBlockingState(isBlocking=true, packages=1, websites=1)'),
      );
    });

    test('deactivateProfile calls updateBlockingState with empty lists when last profile', () async {
      final service = createService();
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      final profiles = makeProfiles();
      await service.activateProfile(profiles[0], allProfiles: profiles);
      fakePlatform.calls.clear();

      await service.deactivateProfile('profile-1', allProfiles: profiles);

      expect(
        fakePlatform.calls,
        contains('updateBlockingState(isBlocking=false, packages=0, websites=0)'),
      );
    });
  });
}
```

- [ ] **Step 3: Run tests to verify they pass**

Run: `cd /Users/calebconfer/Desktop/Projects/phone_lockdown && flutter test test/services/app_blocker_service_test.dart`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add lib/services/app_blocker_service.dart test/services/app_blocker_service_test.dart
git commit -m "refactor: inject PlatformChannelService and SharedPreferences into AppBlockerService"
```

---

## Task 3: Inject SharedPreferences into ProfileManager

**Files:**
- Modify: `lib/services/profile_manager.dart`
- Modify: `test/services/profile_manager_test.dart`

- [ ] **Step 1: Modify ProfileManager to accept injected SharedPreferences**

In `lib/services/profile_manager.dart`, remove the `import 'package:shared_preferences/shared_preferences.dart';` line is NOT needed because prefs is passed in. Actually keep it since `SharedPreferences` type is used.

Replace the class fields and constructor (lines 5-31):

```dart
class ProfileManager extends ChangeNotifier {
  final SharedPreferences _prefs;
  List<Profile> _profiles = [];
  String? _currentProfileId;

  List<Profile> get profiles => _profiles;
  String? get currentProfileId => _currentProfileId;

  Profile get currentProfile {
    return _profiles.firstWhere(
      (p) => p.id == _currentProfileId,
      orElse: () => _profiles.firstWhere(
        (p) => p.name == 'Default',
        orElse: () => _profiles.first,
      ),
    );
  }

  ProfileManager({required SharedPreferences prefs}) : _prefs = prefs {
    _init();
  }

  Future<void> _init() async {
    await loadProfiles();
    _ensureDefaultProfile();
    await _migrateLegacyCode();
    notifyListeners();
  }
```

Replace `loadProfiles()` (lines 33-53) to use `_prefs`:

```dart
  Future<void> loadProfiles() async {
    final savedProfiles = _prefs.getString('savedProfiles');

    if (savedProfiles != null) {
      _profiles = Profile.decodeList(savedProfiles);
    } else {
      final defaultProfile = Profile.defaultProfile();
      _profiles = [defaultProfile];
      _currentProfileId = defaultProfile.id;
    }

    final savedId = _prefs.getString('currentProfileId');
    if (savedId != null && _profiles.any((p) => p.id == savedId)) {
      _currentProfileId = savedId;
    } else {
      _currentProfileId = _profiles.first.id;
    }

    notifyListeners();
  }
```

Replace `saveProfiles()` (lines 55-61) to use `_prefs`:

```dart
  Future<void> saveProfiles() async {
    await _prefs.setString('savedProfiles', Profile.encodeList(_profiles));
    if (_currentProfileId != null) {
      await _prefs.setString('currentProfileId', _currentProfileId!);
    }
  }
```

Replace `_migrateLegacyCode()` (lines 163-178) to use `_prefs`:

```dart
  Future<void> _migrateLegacyCode() async {
    final legacyCode = _prefs.getString('savedCodeValue');
    if (legacyCode == null) return;

    final defaultProfile = _profiles.cast<Profile?>().firstWhere(
          (p) => p!.name == 'Default',
          orElse: () => _profiles.isNotEmpty ? _profiles.first : null,
        );
    if (defaultProfile != null && defaultProfile.unlockCode == null) {
      defaultProfile.unlockCode = legacyCode;
      await saveProfiles();
    }
    await _prefs.remove('savedCodeValue');
  }
```

- [ ] **Step 2: Update ProfileManager tests to inject SharedPreferences**

Replace `test/services/profile_manager_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phone_lockdown/models/profile.dart';
import 'package:phone_lockdown/services/profile_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('Profile JSON round-trip', () {
    test('encodeList and decodeList are inverses', () {
      final profiles = [
        Profile(
          id: 'test-id-1',
          name: 'Work',
          blockedAppPackages: ['com.twitter.android'],
          blockedWebsites: ['twitter.com'],
          unlockCode: 'abc123',
          failsafeMinutes: 60,
        ),
        Profile(
          id: 'test-id-2',
          name: 'Study',
          blockedAppPackages: ['com.instagram.android', 'com.reddit.frontpage'],
          blockedWebsites: ['instagram.com', 'reddit.com'],
          failsafeMinutes: 120,
        ),
      ];

      final encoded = Profile.encodeList(profiles);
      final decoded = Profile.decodeList(encoded);

      expect(decoded.length, 2);
      expect(decoded[0].id, 'test-id-1');
      expect(decoded[0].name, 'Work');
      expect(decoded[0].blockedAppPackages, ['com.twitter.android']);
      expect(decoded[0].blockedWebsites, ['twitter.com']);
      expect(decoded[0].unlockCode, 'abc123');
      expect(decoded[0].failsafeMinutes, 60);
      expect(decoded[1].id, 'test-id-2');
      expect(decoded[1].name, 'Study');
      expect(decoded[1].blockedAppPackages, ['com.instagram.android', 'com.reddit.frontpage']);
      expect(decoded[1].unlockCode, isNull);
    });

    test('Profile.fromJson uses default failsafeMinutes when missing', () {
      final json = {
        'id': 'test-id',
        'name': 'Test',
        'iconCodePoint': 0xe7f5,
        'blockedAppPackages': <String>[],
        'blockedWebsites': <String>[],
      };
      final profile = Profile.fromJson(json);
      expect(profile.failsafeMinutes, 1440);
    });
  });

  group('ProfileManager CRUD', () {
    test('starts with default profile', () async {
      final manager = ProfileManager(prefs: prefs);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      expect(manager.profiles.length, 1);
      expect(manager.profiles.first.name, 'Default');
      expect(manager.currentProfileId, isNotNull);
    });

    test('addProfile creates new profile and sets it current', () async {
      final manager = ProfileManager(prefs: prefs);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      manager.addProfile(name: 'Work');

      expect(manager.profiles.length, 2);
      expect(manager.profiles.last.name, 'Work');
      expect(manager.currentProfileId, manager.profiles.last.id);
    });

    test('deleteProfile removes profile and falls back to first', () async {
      final manager = ProfileManager(prefs: prefs);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      manager.addProfile(name: 'Work');
      final workId = manager.profiles.last.id;

      manager.deleteProfile(workId);

      expect(manager.profiles.length, 1);
      expect(manager.profiles.first.name, 'Default');
    });

    test('deleteProfile ensures default profile always exists', () async {
      final manager = ProfileManager(prefs: prefs);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      final defaultId = manager.profiles.first.id;
      manager.deleteProfile(defaultId);

      expect(manager.profiles.length, 1);
      expect(manager.profiles.first.name, 'Default');
    });

    test('updateProfile modifies fields', () async {
      final manager = ProfileManager(prefs: prefs);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      final id = manager.profiles.first.id;
      manager.updateProfile(
        id: id,
        name: 'Updated',
        blockedAppPackages: ['com.test.app'],
        blockedWebsites: ['test.com'],
        failsafeMinutes: 30,
      );

      final updated = manager.profiles.first;
      expect(updated.name, 'Updated');
      expect(updated.blockedAppPackages, ['com.test.app']);
      expect(updated.blockedWebsites, ['test.com']);
      expect(updated.failsafeMinutes, 30);
    });

    test('findProfileByCode returns matching profile', () async {
      final manager = ProfileManager(prefs: prefs);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      final id = manager.profiles.first.id;
      manager.updateProfile(id: id, unlockCode: 'secret-code');

      final found = manager.findProfileByCode('secret-code');
      expect(found, isNotNull);
      expect(found!.id, id);
    });

    test('findProfileByCode returns null for non-existent code', () async {
      final manager = ProfileManager(prefs: prefs);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      expect(manager.findProfileByCode('non-existent'), isNull);
    });
  });

  group('ProfileManager legacy migration', () {
    test('migrates savedCodeValue to default profile unlockCode', () async {
      SharedPreferences.setMockInitialValues({
        'savedCodeValue': 'legacy-code-123',
      });
      final migrationPrefs = await SharedPreferences.getInstance();

      final manager = ProfileManager(prefs: migrationPrefs);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      expect(manager.profiles.first.unlockCode, 'legacy-code-123');
      expect(migrationPrefs.getString('savedCodeValue'), isNull);
    });
  });
}
```

- [ ] **Step 3: Run tests to verify they pass**

Run: `cd /Users/calebconfer/Desktop/Projects/phone_lockdown && flutter test test/services/profile_manager_test.dart`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add lib/services/profile_manager.dart test/services/profile_manager_test.dart
git commit -m "refactor: inject SharedPreferences into ProfileManager"
```

---

## Task 4: Update main.dart and UI Screens to Use Injected Services

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/screens/permissions_screen.dart`
- Modify: `lib/screens/onboarding_screen.dart`
- Modify: `lib/screens/app_picker_screen.dart`

- [ ] **Step 1: Update main.dart to create and inject dependencies**

Replace `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/app_blocker_service.dart';
import 'services/platform_channel_service.dart';
import 'services/profile_manager.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final onboardingComplete = prefs.getBool('onboardingComplete') ?? false;
  final platform = MethodChannelPlatformService();
  runApp(PhoneLockdownApp(
    onboardingComplete: onboardingComplete,
    prefs: prefs,
    platform: platform,
  ));
}

class PhoneLockdownApp extends StatelessWidget {
  final bool onboardingComplete;
  final SharedPreferences prefs;
  final PlatformChannelService platform;

  const PhoneLockdownApp({
    super.key,
    required this.onboardingComplete,
    required this.prefs,
    required this.platform,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<PlatformChannelService>.value(value: platform),
        ChangeNotifierProvider(
          create: (_) => ProfileManager(prefs: prefs),
        ),
        ChangeNotifierProvider(
          create: (_) => AppBlockerService(platform: platform, prefs: prefs),
        ),
      ],
      child: MaterialApp(
        title: 'Phone Lockdown',
        theme: AppTheme.dark,
        initialRoute: onboardingComplete ? '/home' : '/onboarding',
        routes: {
          '/home': (_) => const HomeScreen(),
          '/onboarding': (_) => const OnboardingScreen(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
```

- [ ] **Step 2: Update permissions_screen.dart to use injected PlatformChannelService**

In `lib/screens/permissions_screen.dart`, replace the import and usages:

Replace:
```dart
import '../services/platform_channel_service.dart';
```
with nothing (remove this import entirely).

Replace line 54:
```dart
                    PlatformChannelService.openAccessibilitySettings(),
```
with:
```dart
                    context.read<PlatformChannelService>().openAccessibilitySettings(),
```

Replace line 85:
```dart
                onGrant: () => PlatformChannelService.requestDeviceAdmin(),
```
with:
```dart
                onGrant: () => context.read<PlatformChannelService>().requestDeviceAdmin(),
```

Add import at the top:
```dart
import '../services/platform_channel_service.dart';
```

(Actually the import stays the same since we still need the type. The only change is from static calls to instance calls via Provider.)

- [ ] **Step 3: Update onboarding_screen.dart to use injected PlatformChannelService**

In `lib/screens/onboarding_screen.dart`, replace line 146:
```dart
          onGrant: () => PlatformChannelService.openAccessibilitySettings(),
```
with:
```dart
          onGrant: () => context.read<PlatformChannelService>().openAccessibilitySettings(),
```

- [ ] **Step 4: Update app_picker_screen.dart to use injected PlatformChannelService**

In `lib/screens/app_picker_screen.dart`, replace line 32:
```dart
      final apps = await PlatformChannelService.getInstalledApps();
```
with:
```dart
      final platform = context.read<PlatformChannelService>();
      final apps = await platform.getInstalledApps();
```

Add import at the top (it already has `import '../services/platform_channel_service.dart';` so no change needed).

- [ ] **Step 5: Run full Flutter test suite**

Run: `cd /Users/calebconfer/Desktop/Projects/phone_lockdown && flutter test`
Expected: All tests pass

- [ ] **Step 6: Run Flutter analyze**

Run: `cd /Users/calebconfer/Desktop/Projects/phone_lockdown && flutter analyze`
Expected: No errors

- [ ] **Step 7: Commit**

```bash
git add lib/main.dart lib/screens/permissions_screen.dart lib/screens/onboarding_screen.dart lib/screens/app_picker_screen.dart
git commit -m "refactor: wire up dependency injection in main.dart and UI screens"
```

---

## Task 5: Extract PermissionManager from MainActivity

**Files:**
- Create: `android/app/src/main/kotlin/com/example/phone_lockdown/PermissionManager.kt`
- Modify: `android/app/src/main/kotlin/com/example/phone_lockdown/MainActivity.kt`

- [ ] **Step 1: Create PermissionManager.kt**

Create `android/app/src/main/kotlin/com/example/phone_lockdown/PermissionManager.kt`:

```kotlin
package com.example.phone_lockdown

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.provider.Settings

class PermissionManager(private val context: Context) {

    fun checkPermissions(): Map<String, Boolean> {
        return mapOf(
            "accessibility" to isAccessibilityServiceEnabled(),
            "deviceAdmin" to isDeviceAdminEnabled(),
            "vpn" to (VpnService.prepare(context) == null),
        )
    }

    fun isAccessibilityServiceEnabled(): Boolean {
        val serviceName = "${context.packageName}/${LockdownAccessibilityService::class.java.canonicalName}"
        val enabledServices = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabledServices.contains(serviceName)
    }

    fun isDeviceAdminEnabled(): Boolean {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val adminComponent = ComponentName(context, LockdownDeviceAdmin::class.java)
        return dpm.isAdminActive(adminComponent)
    }

    fun openAccessibilitySettings() {
        try {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            val serviceName = "${context.packageName}/${LockdownAccessibilityService::class.java.canonicalName}"
            val bundle = android.os.Bundle()
            bundle.putString(":settings:fragment_args_key", serviceName)
            intent.putExtra(":settings:fragment_args_key", serviceName)
            intent.putExtra(":settings:show_fragment_args", bundle)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        } catch (e: Exception) {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        }
    }

    fun openUsageStatsSettings() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    fun requestDeviceAdmin() {
        val adminComponent = ComponentName(context, LockdownDeviceAdmin::class.java)
        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
            putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent)
            putExtra(
                DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                "Phone Lockdown needs device admin to prevent uninstallation while blocking is active."
            )
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/calebconfer/Desktop/Projects/phone_lockdown/android && ./gradlew compileDebugKotlin 2>&1 | tail -5`
Expected: BUILD SUCCESSFUL

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/example/phone_lockdown/PermissionManager.kt
git commit -m "refactor: extract PermissionManager from MainActivity"
```

---

## Task 6: Extract VpnController from MainActivity

**Files:**
- Create: `android/app/src/main/kotlin/com/example/phone_lockdown/VpnController.kt`

- [ ] **Step 1: Create VpnController.kt**

Create `android/app/src/main/kotlin/com/example/phone_lockdown/VpnController.kt`:

```kotlin
package com.example.phone_lockdown

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.MethodChannel

class VpnController(private val context: Context) {

    companion object {
        const val VPN_REQUEST_CODE = 1001
        private const val TAG = "VpnController"
    }

    var pendingVpnResult: MethodChannel.Result? = null

    fun prepareVpn(activity: Activity, result: MethodChannel.Result) {
        val intent = VpnService.prepare(activity)
        if (intent == null) {
            result.success(true)
        } else {
            pendingVpnResult = result
            activity.startActivityForResult(intent, VPN_REQUEST_CODE)
        }
    }

    fun handleActivityResult(requestCode: Int, resultCode: Int): Boolean {
        if (requestCode == VPN_REQUEST_CODE) {
            val approved = resultCode == Activity.RESULT_OK
            pendingVpnResult?.success(approved)
            pendingVpnResult = null
            return true
        }
        return false
    }

    fun startVpnService() {
        try {
            val intent = Intent(context, LockdownVpnService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start VPN service", e)
        }
    }

    fun stopVpnService() {
        try {
            val intent = Intent(context, LockdownVpnService::class.java).apply {
                action = "STOP"
            }
            context.startService(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop VPN service", e)
        }
    }

    fun isVpnActive(): Boolean {
        return LockdownVpnService.instance != null
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/calebconfer/Desktop/Projects/phone_lockdown/android && ./gradlew compileDebugKotlin 2>&1 | tail -5`
Expected: BUILD SUCCESSFUL

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/example/phone_lockdown/VpnController.kt
git commit -m "refactor: extract VpnController from MainActivity"
```

---

## Task 7: Extract BlockingStateManager from MainActivity

**Files:**
- Create: `android/app/src/main/kotlin/com/example/phone_lockdown/BlockingStateManager.kt`

- [ ] **Step 1: Create BlockingStateManager.kt**

Create `android/app/src/main/kotlin/com/example/phone_lockdown/BlockingStateManager.kt`:

```kotlin
package com.example.phone_lockdown

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

class BlockingStateManager(
    private val context: Context,
    private val vpnController: VpnController,
) {
    companion object {
        private const val TAG = "BlockingStateManager"
    }

    fun updateBlockingState(
        isBlocking: Boolean,
        packages: List<String>,
        websites: List<String>,
        activeProfileBlocks: List<Map<String, Any>>? = null
    ) {
        val prefs = PrefsHelper.getPrefs(context)
        val editor = prefs.edit()
            .putBoolean("isBlocking", isBlocking)
            .putStringSet("blockedPackages", packages.toSet())
            .putStringSet("blockedWebsites", websites.toSet())

        if (activeProfileBlocks != null) {
            val jsonArray = JSONArray()
            for (block in activeProfileBlocks) {
                val obj = JSONObject()
                obj.put("profileId", block["profileId"])
                val pkgArray = JSONArray()
                @Suppress("UNCHECKED_CAST")
                for (pkg in (block["blockedPackages"] as? List<String>) ?: emptyList()) {
                    pkgArray.put(pkg)
                }
                obj.put("blockedPackages", pkgArray)
                val webArray = JSONArray()
                @Suppress("UNCHECKED_CAST")
                for (web in (block["blockedWebsites"] as? List<String>) ?: emptyList()) {
                    webArray.put(web)
                }
                obj.put("blockedWebsites", webArray)
                jsonArray.put(obj)
            }
            editor.putString("activeProfileBlocks", jsonArray.toString())
        }

        editor.apply()

        LockdownAccessibilityService.isBlockingActive = isBlocking
        LockdownAccessibilityService.blockedPackages = packages.toSet()
        LockdownAccessibilityService.blockedWebsites = websites.toSet()

        if (isBlocking && websites.isNotEmpty()) {
            LockdownVpnService.blockedWebsites = websites.toSet()
            if (LockdownVpnService.instance == null && VpnService.prepare(context) == null) {
                vpnController.startVpnService()
            }
        } else {
            vpnController.stopVpnService()
        }
    }

    fun getEnforcementState(): Map<String, Any> {
        val prefs = PrefsHelper.getPrefs(context)
        val isBlocking = prefs.getBoolean("isBlocking", false)
        val blocksJson = prefs.getString("activeProfileBlocks", "[]")
        val blocks = JSONArray(blocksJson)
        val activeProfileIds = mutableListOf<String>()
        for (i in 0 until blocks.length()) {
            activeProfileIds.add(blocks.getJSONObject(i).getString("profileId"))
        }
        return mapOf(
            "isBlocking" to isBlocking,
            "activeProfileIds" to activeProfileIds,
        )
    }

    fun scheduleFailsafeAlarm(profileId: String, failsafeMillis: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, FailsafeAlarmReceiver::class.java).apply {
            putExtra("profileId", profileId)
        }
        val requestCode = profileId.hashCode()
        val pendingIntent = PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val triggerTime = System.currentTimeMillis() + failsafeMillis

        val prefs = PrefsHelper.getPrefs(context)
        val alarmsJson = prefs.getString("failsafeAlarms", "[]")
        val alarms = JSONArray(alarmsJson)
        val updatedAlarms = JSONArray()
        for (i in 0 until alarms.length()) {
            val obj = alarms.getJSONObject(i)
            if (obj.getString("profileId") != profileId) {
                updatedAlarms.put(obj)
            }
        }
        val newAlarm = JSONObject()
        newAlarm.put("profileId", profileId)
        newAlarm.put("alarmTimeMillis", triggerTime)
        updatedAlarms.put(newAlarm)
        prefs.edit().putString("failsafeAlarms", updatedAlarms.toString()).apply()

        try {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent
            )
        } catch (e: SecurityException) {
            Log.w(TAG, "Exact alarm not allowed, using inexact alarm", e)
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
        }
    }

    fun cancelFailsafeAlarm(profileId: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, FailsafeAlarmReceiver::class.java)
        val requestCode = profileId.hashCode()
        val pendingIntent = PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)

        val prefs = PrefsHelper.getPrefs(context)
        val alarmsJson = prefs.getString("failsafeAlarms", "[]")
        val alarms = JSONArray(alarmsJson)
        val updatedAlarms = JSONArray()
        for (i in 0 until alarms.length()) {
            val obj = alarms.getJSONObject(i)
            if (obj.getString("profileId") != profileId) {
                updatedAlarms.put(obj)
            }
        }
        prefs.edit().putString("failsafeAlarms", updatedAlarms.toString()).apply()
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/calebconfer/Desktop/Projects/phone_lockdown/android && ./gradlew compileDebugKotlin 2>&1 | tail -5`
Expected: BUILD SUCCESSFUL

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/example/phone_lockdown/BlockingStateManager.kt
git commit -m "refactor: extract BlockingStateManager from MainActivity"
```

---

## Task 8: Extract MethodChannelHandler and Rewrite MainActivity

**Files:**
- Create: `android/app/src/main/kotlin/com/example/phone_lockdown/MethodChannelHandler.kt`
- Modify: `android/app/src/main/kotlin/com/example/phone_lockdown/MainActivity.kt`

- [ ] **Step 1: Create MethodChannelHandler.kt**

Create `android/app/src/main/kotlin/com/example/phone_lockdown/MethodChannelHandler.kt`:

```kotlin
package com.example.phone_lockdown

import android.app.Activity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MethodChannelHandler(
    private val activity: Activity,
    private val permissionManager: PermissionManager,
    private val vpnController: VpnController,
    private val blockingStateManager: BlockingStateManager,
    private val appListHelper: AppListHelper,
) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getInstalledApps" -> {
                result.success(appListHelper.getInstalledApps())
            }
            "checkPermissions" -> {
                result.success(permissionManager.checkPermissions())
            }
            "updateBlockingState" -> {
                val isBlocking = call.argument<Boolean>("isBlocking") ?: false
                val packages = call.argument<List<String>>("blockedPackages") ?: emptyList()
                val websites = call.argument<List<String>>("blockedWebsites") ?: emptyList()
                val activeProfileBlocks = call.argument<List<Map<String, Any>>>("activeProfileBlocks")
                blockingStateManager.updateBlockingState(isBlocking, packages, websites, activeProfileBlocks)
                result.success(null)
            }
            "getEnforcementState" -> {
                result.success(blockingStateManager.getEnforcementState())
            }
            "openAccessibilitySettings" -> {
                permissionManager.openAccessibilitySettings()
                result.success(null)
            }
            "openUsageStatsSettings" -> {
                permissionManager.openUsageStatsSettings()
                result.success(null)
            }
            "requestDeviceAdmin" -> {
                permissionManager.requestDeviceAdmin()
                result.success(null)
            }
            "prepareVpn" -> {
                vpnController.prepareVpn(activity, result)
            }
            "startVpn" -> {
                vpnController.startVpnService()
                result.success(null)
            }
            "stopVpn" -> {
                vpnController.stopVpnService()
                result.success(null)
            }
            "isVpnActive" -> {
                result.success(vpnController.isVpnActive())
            }
            "scheduleFailsafeAlarm" -> {
                val profileId = call.argument<String>("profileId") ?: ""
                val failsafeMillis = call.argument<Int>("failsafeMillis") ?: 0
                blockingStateManager.scheduleFailsafeAlarm(profileId, failsafeMillis.toLong())
                result.success(null)
            }
            "cancelFailsafeAlarm" -> {
                val profileId = call.argument<String>("profileId") ?: ""
                blockingStateManager.cancelFailsafeAlarm(profileId)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
```

- [ ] **Step 2: Rewrite MainActivity.kt as thin shell**

Replace the entire `android/app/src/main/kotlin/com/example/phone_lockdown/MainActivity.kt`:

```kotlin
package com.example.phone_lockdown

import android.content.Intent
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.phone_lockdown/blocker"
    private lateinit var vpnController: VpnController

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        scheduleServiceMonitor()

        val permissionManager = PermissionManager(this)
        vpnController = VpnController(this)
        val blockingStateManager = BlockingStateManager(this, vpnController)
        val appListHelper = AppListHelper(applicationContext)

        val handler = MethodChannelHandler(
            activity = this,
            permissionManager = permissionManager,
            vpnController = vpnController,
            blockingStateManager = blockingStateManager,
            appListHelper = appListHelper,
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler(handler)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (!vpnController.handleActivityResult(requestCode, resultCode)) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    private fun scheduleServiceMonitor() {
        val workRequest = PeriodicWorkRequestBuilder<ServiceMonitorWorker>(
            15, TimeUnit.MINUTES
        ).build()

        WorkManager.getInstance(applicationContext).enqueueUniquePeriodicWork(
            ServiceMonitorWorker.WORK_NAME,
            ExistingPeriodicWorkPolicy.KEEP,
            workRequest
        )
    }
}
```

- [ ] **Step 3: Verify it compiles**

Run: `cd /Users/calebconfer/Desktop/Projects/phone_lockdown/android && ./gradlew compileDebugKotlin 2>&1 | tail -5`
Expected: BUILD SUCCESSFUL

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/example/phone_lockdown/MethodChannelHandler.kt android/app/src/main/kotlin/com/example/phone_lockdown/MainActivity.kt
git commit -m "refactor: rewrite MainActivity as thin shell with MethodChannelHandler"
```

---

## Task 9: Add getEnforcementState to Flutter PlatformChannelService

**Files:**
- Modify: `lib/services/platform_channel_service.dart`

- [ ] **Step 1: Add getEnforcementState to the abstract interface and implementation**

In `lib/services/platform_channel_service.dart`, add to the abstract class after `isVpnActive`:

```dart
  Future<Map<String, dynamic>> getEnforcementState();
```

Add to `MethodChannelPlatformService` after `isVpnActive`:

```dart
  @override
  Future<Map<String, dynamic>> getEnforcementState() async {
    final Map<dynamic, dynamic> result =
        await _channel.invokeMethod('getEnforcementState');
    return result.map((k, v) => MapEntry(k as String, v));
  }
```

- [ ] **Step 2: Add getEnforcementState to FakePlatformService in tests**

In `test/services/app_blocker_service_test.dart`, add a field and method to `FakePlatformService`:

Add field after `permissionsResult`:
```dart
  List<String> enforcementActiveProfileIds = [];
```

Add method after `isVpnActive`:
```dart
  @override
  Future<Map<String, dynamic>> getEnforcementState() async {
    calls.add('getEnforcementState');
    return {
      'isBlocking': enforcementActiveProfileIds.isNotEmpty,
      'activeProfileIds': enforcementActiveProfileIds,
    };
  }
```

- [ ] **Step 3: Run Flutter analyze**

Run: `cd /Users/calebconfer/Desktop/Projects/phone_lockdown && flutter analyze`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/services/platform_channel_service.dart test/services/app_blocker_service_test.dart
git commit -m "feat: add getEnforcementState method channel for reconciliation"
```

---

## Task 10: Add Reconciliation to AppBlockerService

**Files:**
- Modify: `lib/services/app_blocker_service.dart`
- Modify: `test/services/app_blocker_service_test.dart`

- [ ] **Step 1: Write failing reconciliation tests**

Add to `test/services/app_blocker_service_test.dart`, after the last group:

```dart
  group('AppBlockerService reconciliation', () {
    test('reconcile removes Flutter locks that Android deactivated', () async {
      // Simulate: Flutter thinks profile-1 is active, but Android says it's not
      SharedPreferences.setMockInitialValues({
        'activeLocks': jsonEncode([
          ActiveLock(
            profileId: 'profile-1',
            lockStartTime: DateTime.now(),
            failsafeMinutes: 60,
          ).toJson(),
        ]),
      });
      final reconPrefs = await SharedPreferences.getInstance();
      final reconPlatform = FakePlatformService();
      reconPlatform.enforcementActiveProfileIds = []; // Android says nothing active

      final service = AppBlockerService(platform: reconPlatform, prefs: reconPrefs);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      // Before reconciliation, Flutter thinks it's blocking
      expect(service.isBlocking, isTrue);

      final profiles = makeProfiles();
      await service.reconcileWithAndroid(profiles);

      // After reconciliation, Flutter agrees with Android
      expect(service.isBlocking, isFalse);
      expect(service.activeProfileIds, isEmpty);
    });

    test('reconcile cleans up Android orphans not in Flutter', () async {
      final service = createService();
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      // Android thinks profile-1 is active, but Flutter has no locks
      fakePlatform.enforcementActiveProfileIds = ['profile-1'];

      final profiles = makeProfiles();
      await service.reconcileWithAndroid(profiles);

      expect(service.isBlocking, isFalse);
      expect(fakePlatform.calls, contains('cancelFailsafeAlarm(profile-1)'));
    });

    test('reconcile is a no-op when both sides agree', () async {
      final service = createService();
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      final profiles = makeProfiles();
      await service.activateProfile(profiles[0], allProfiles: profiles);
      fakePlatform.calls.clear();

      // Android agrees profile-1 is active
      fakePlatform.enforcementActiveProfileIds = ['profile-1'];

      await service.reconcileWithAndroid(profiles);

      // Still blocking, no unexpected calls
      expect(service.isBlocking, isTrue);
      expect(service.activeProfileIds, contains('profile-1'));
    });

    test('reconcile handles both sides empty', () async {
      final service = createService();
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      fakePlatform.enforcementActiveProfileIds = [];

      final profiles = makeProfiles();
      await service.reconcileWithAndroid(profiles);

      expect(service.isBlocking, isFalse);
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/calebconfer/Desktop/Projects/phone_lockdown && flutter test test/services/app_blocker_service_test.dart`
Expected: FAIL — `reconcileWithAndroid` method does not exist yet

- [ ] **Step 3: Implement reconcileWithAndroid in AppBlockerService**

In `lib/services/app_blocker_service.dart`, add this method after `restoreTimers` and before `prepareVpn`:

```dart
  /// Reconcile Flutter state with Android enforcement state on app startup.
  /// Android is authoritative for enforcement; Flutter is authoritative for profiles.
  Future<void> reconcileWithAndroid(List<Profile> allProfiles) async {
    final enforcement = await _platform.getEnforcementState();
    final androidActiveIds =
        Set<String>.from((enforcement['activeProfileIds'] as List?) ?? []);
    final flutterActiveIds = _activeLocks.keys.toSet();

    // Profiles that Android deactivated (failsafe fired while Flutter was dead)
    for (final id in flutterActiveIds.difference(androidActiveIds)) {
      final lock = _activeLocks.remove(id);
      lock?.timer?.cancel();
    }

    // Profiles that shouldn't be active on Android (orphans)
    for (final id in androidActiveIds.difference(flutterActiveIds)) {
      await _platform.cancelFailsafeAlarm(profileId: id);
    }

    // Persist corrected state and reapply
    await _saveActiveLocks();
    if (_activeLocks.isNotEmpty) {
      await _recomputeAndApply(allProfiles);
    } else {
      await _platform.updateBlockingState(
        isBlocking: false,
        blockedPackages: [],
        blockedWebsites: [],
        activeProfileBlocks: [],
      );
    }
    notifyListeners();
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/calebconfer/Desktop/Projects/phone_lockdown && flutter test test/services/app_blocker_service_test.dart`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add lib/services/app_blocker_service.dart test/services/app_blocker_service_test.dart
git commit -m "feat: add reconcileWithAndroid to AppBlockerService"
```

---

## Task 11: Call Reconciliation on App Startup

**Files:**
- Modify: `lib/screens/home_screen.dart`

- [ ] **Step 1: Add reconciliation call in HomeScreen.initState**

In `lib/screens/home_screen.dart`, replace the `initState` method (lines 22-31):

```dart
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appBlocker = context.read<AppBlockerService>();
      final profileManager = context.read<ProfileManager>();
      appBlocker.restoreTimers(profileManager.profiles);
      appBlocker.reconcileWithAndroid(profileManager.profiles);
    });
    _startCountdownRefresh();
  }
```

- [ ] **Step 2: Run Flutter analyze**

Run: `cd /Users/calebconfer/Desktop/Projects/phone_lockdown && flutter analyze`
Expected: No errors

- [ ] **Step 3: Run full test suite**

Run: `cd /Users/calebconfer/Desktop/Projects/phone_lockdown && flutter test`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat: call reconcileWithAndroid on app startup"
```

---

## Task 12: Add Ordering Guarantee to updateBlockingState

**Files:**
- Modify: `lib/services/app_blocker_service.dart`

- [ ] **Step 1: Reorder _saveActiveLocks to happen after platform call succeeds**

In `lib/services/app_blocker_service.dart`, modify `activateProfile` to save after the platform call. Replace the method:

```dart
  Future<bool> activateProfile(Profile profile, {required List<Profile> allProfiles}) async {
    if (!_isAccessibilityEnabled) {
      debugPrint('Accessibility service not enabled');
      return false;
    }

    final lock = ActiveLock(
      profileId: profile.id,
      lockStartTime: DateTime.now(),
      failsafeMinutes: profile.failsafeMinutes,
    );

    _activeLocks[profile.id] = lock;
    _startFailsafeTimer(lock, allProfiles);

    // Send intent to Android first, then persist Flutter state
    await _recomputeAndApply(allProfiles);
    await _saveActiveLocks();

    try {
      await _platform.scheduleFailsafeAlarm(
        profileId: profile.id,
        failsafeMillis: lock.remaining.inMilliseconds,
      );
    } catch (e) {
      debugPrint('Failed to schedule failsafe alarm: $e');
    }

    notifyListeners();
    return true;
  }
```

Similarly modify `deactivateProfile`:

```dart
  Future<bool> deactivateProfile(String profileId, {required List<Profile> allProfiles}) async {
    final lock = _activeLocks.remove(profileId);
    if (lock == null) return false;

    lock.timer?.cancel();

    // Send intent to Android first, then persist Flutter state
    await _recomputeAndApply(allProfiles);
    await _saveActiveLocks();

    try {
      await _platform.cancelFailsafeAlarm(profileId: profileId);
    } catch (e) {
      debugPrint('Failed to cancel failsafe alarm: $e');
    }

    notifyListeners();
    return true;
  }
```

- [ ] **Step 2: Run tests to verify ordering change doesn't break anything**

Run: `cd /Users/calebconfer/Desktop/Projects/phone_lockdown && flutter test`
Expected: All tests pass

- [ ] **Step 3: Commit**

```bash
git add lib/services/app_blocker_service.dart
git commit -m "fix: persist Flutter state only after Android acknowledges update"
```

---

## Task 13: Final Verification — Build and Deploy

- [ ] **Step 1: Run full Flutter test suite**

Run: `cd /Users/calebconfer/Desktop/Projects/phone_lockdown && flutter test`
Expected: All tests pass

- [ ] **Step 2: Run Flutter analyze**

Run: `cd /Users/calebconfer/Desktop/Projects/phone_lockdown && flutter analyze`
Expected: No errors

- [ ] **Step 3: Build Android debug APK**

Run: `cd /Users/calebconfer/Desktop/Projects/phone_lockdown/android && ./gradlew assembleDebug 2>&1 | tail -10`
Expected: BUILD SUCCESSFUL

- [ ] **Step 4: Check for connected device and install**

Run: `adb devices`
If a device is connected:
Run: `cd /Users/calebconfer/Desktop/Projects/phone_lockdown/android && ./gradlew installDebug`
Expected: Installation succeeds

- [ ] **Step 5: Push to GitHub**

Run: `git push`
Expected: Push succeeds
