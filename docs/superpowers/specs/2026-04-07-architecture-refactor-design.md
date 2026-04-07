# Architecture Refactor Design

**Date:** 2026-04-07
**Goal:** Address three architectural concerns — God Activity, dual state persistence, and lack of dependency injection — in a dedicated cleanup pass.
**Approach:** Clean boundaries with ownership split. No user-facing behavior changes.

---

## 1. MainActivity Decomposition

### Problem

MainActivity.kt (326 lines) handles method channel dispatch, permission checking, VPN management, app listing, and accessibility settings navigation. Too many responsibilities in one class.

### Design

Split into focused classes, each with a single responsibility:

**MainActivity.kt (~50 lines)**
- `onCreate`: instantiate controllers, wire up `MethodChannelHandler`
- `onActivityResult`: delegate to `VpnController` / `PermissionManager`

**MethodChannelHandler.kt (~80 lines)**
- Receives all method channel calls via `setMethodCallHandler`
- Routes to the appropriate controller based on method name
- Returns results to Flutter
- Takes controllers as constructor parameters (testable)

**PermissionManager.kt (~60 lines)**
- `checkPermissions()` — returns map of accessibility, deviceAdmin, vpn status
- `requestDeviceAdmin(activity)` — triggers device admin intent
- `openAccessibilitySettings(activity)` — opens system accessibility settings
- `openUsageStatsSettings(activity)` — opens usage stats settings

**VpnController.kt (~50 lines)**
- `prepareVpn(activity)` / `startVpn(context)` / `stopVpn(context)`
- `isVpnActive()` — checks VPN service state
- Handles `VPN_REQUEST_CODE` activity result

**BlockingStateManager.kt (~80 lines)**
- `updateBlockingState(isBlocking, blockedPackages, blockedWebsites, activeProfileBlocks)` — writes to PrefsHelper, updates AccessibilityService and VpnService static state
- `getEnforcementState()` — NEW: returns current enforcement state for Flutter reconciliation
- `scheduleFailsafeAlarm(profileId, millis)` / `cancelFailsafeAlarm(profileId)`
- Owns the enforcement truth via encrypted prefs (PrefsHelper)

**Unchanged:**
- `AppListHelper` already exists as a separate class — app listing routes through it
- `PrefsHelper` remains the low-level encrypted prefs wrapper
- `LockdownAccessibilityService`, `LockdownVpnService`, `FailsafeAlarmReceiver`, `ServiceMonitorWorker` unchanged

### File Impact

| File | Action |
|------|--------|
| `MainActivity.kt` | Rewrite — thin shell delegating to controllers |
| `MethodChannelHandler.kt` | New — method channel dispatch |
| `PermissionManager.kt` | New — permission logic extracted from MainActivity |
| `VpnController.kt` | New — VPN lifecycle extracted from MainActivity |
| `BlockingStateManager.kt` | New — enforcement state logic extracted from MainActivity |

---

## 2. State Ownership & Reconciliation

### Problem

Blocking state lives in both Flutter SharedPreferences (unencrypted) and Android SharedPreferences (encrypted) independently. No reconciliation mechanism. If the app is killed mid-update or the failsafe fires while Flutter is dead, the two sides can drift.

### Ownership Model

**Android owns enforcement state (authoritative):**
- Whether blocking is currently active
- Which packages are blocked
- Which websites are blocked
- Per-profile block mappings (for failsafe deactivation of individual profiles)
- Failsafe alarm schedules

**Flutter owns UI/profile state (authoritative):**
- Profile definitions (name, blocked apps, blocked websites, unlock code, failsafe duration)
- Which profiles the user considers "active" (activeLocks)
- Onboarding completion state

### Reconciliation Protocol

Runs on every Flutter app startup, after loading Flutter's own state:

1. Flutter calls `getEnforcementState()` via method channel
2. Android returns: `{ isBlocking: bool, activeProfileIds: List<String> }`
3. Flutter compares its `activeLocks` map against Android's `activeProfileIds`:
   - **Profile active in Flutter but NOT in Android** — failsafe fired while Flutter was dead. Flutter deactivates the profile locally, updates UI.
   - **Profile active in Android but NOT in Flutter** — unexpected state. Flutter tells Android to deactivate that profile.
   - **Both agree** — no action needed.
4. After reconciliation, Flutter and Android state are consistent.

### Method Channel Changes

| Method | Direction | Change |
|--------|-----------|--------|
| `getEnforcementState` | Flutter -> Android | **NEW** — query current enforcement truth |
| `updateBlockingState` | Flutter -> Android | **Modified** — Flutter only saves its own state after receiving successful acknowledgment from Android |
| All others | — | Unchanged |

### Ordering Guarantee

Today Flutter calls `updateBlockingState()` and immediately saves its own state, regardless of whether Android succeeded. After this change:

1. Flutter sends intent to Android via `updateBlockingState()`
2. Android persists to encrypted prefs and updates services
3. Android returns success
4. **Only then** does Flutter persist its own state (activeLocks to SharedPreferences)

If the app is killed between steps 2 and 4, the next startup reconciliation will detect the inconsistency and fix it.

---

## 3. Flutter Dependency Injection

### Problem

`PlatformChannelService` is a static class. `AppBlockerService` and `ProfileManager` internally call `SharedPreferences.getInstance()`. This makes unit testing impossible without hitting real platform channels and disk.

### Design

**Abstract PlatformChannelService into an interface:**

```dart
abstract class PlatformChannelService {
  Future<void> updateBlockingState({
    required bool isBlocking,
    required List<String> blockedPackages,
    required List<String> blockedWebsites,
    required List<Map<String, dynamic>> activeProfileBlocks,
  });
  Future<Map<String, dynamic>> getEnforcementState();
  Future<List<Map<String, dynamic>>> getInstalledApps();
  Future<Map<String, bool>> checkPermissions();
  Future<void> prepareVpn();
  Future<void> startVpn();
  Future<void> stopVpn();
  Future<bool> isVpnActive();
  Future<void> openAccessibilitySettings();
  Future<void> requestDeviceAdmin();
  Future<void> openUsageStatsSettings();
  Future<void> scheduleFailsafeAlarm({required String profileId, required int failsafeMillis});
  Future<void> cancelFailsafeAlarm({required String profileId});
}
```

**Concrete implementation:**

```dart
class MethodChannelPlatformService implements PlatformChannelService {
  static const _channel = MethodChannel('com.example.phone_lockdown/blocker');
  // ... actual MethodChannel calls
}
```

**Inject dependencies into services:**

```dart
class AppBlockerService extends ChangeNotifier {
  final PlatformChannelService _platform;
  final SharedPreferences _prefs;

  AppBlockerService({
    required PlatformChannelService platform,
    required SharedPreferences prefs,
  });
}

class ProfileManager extends ChangeNotifier {
  final SharedPreferences _prefs;

  ProfileManager({required SharedPreferences prefs});
}
```

**Wire up in main.dart:**

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final platform = MethodChannelPlatformService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ProfileManager(prefs: prefs),
        ),
        ChangeNotifierProvider(
          create: (_) => AppBlockerService(platform: platform, prefs: prefs),
        ),
      ],
      child: const MyApp(),
    ),
  );
}
```

### What This Enables

- Tests inject a `FakePlatformService` that records calls without touching MethodChannel
- Tests use a real or in-memory `SharedPreferences` instance
- Services have explicit, visible dependencies
- No change to Provider pattern, ChangeNotifier, or widget tree structure

### File Impact

| File | Action |
|------|--------|
| `lib/services/platform_channel_service.dart` | Rewrite — abstract interface + concrete implementation |
| `lib/services/app_blocker_service.dart` | Modify — accept injected dependencies via constructor |
| `lib/services/profile_manager.dart` | Modify — accept injected SharedPreferences via constructor |
| `lib/main.dart` | Modify — create dependencies and pass to providers |

---

## 4. Reconciliation Integration with AppBlockerService

The reconciliation logic lives in `AppBlockerService` since it already manages active locks:

```dart
class AppBlockerService extends ChangeNotifier {
  Future<void> reconcileWithAndroid(List<Profile> allProfiles) async {
    final enforcement = await _platform.getEnforcementState();
    final androidActiveIds = Set<String>.from(enforcement['activeProfileIds']);
    final flutterActiveIds = _activeLocks.keys.toSet();

    // Profiles that Android deactivated (failsafe fired while Flutter dead)
    for (final id in flutterActiveIds.difference(androidActiveIds)) {
      _activeLocks.remove(id);
    }

    // Profiles that shouldn't be active on Android
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
}
```

Called once on app startup from the widget that has access to both services (e.g., `HomeScreen.initState` or a startup widget).

---

## 5. Testing Strategy

### Android Unit Tests

- `BlockingStateManager` — test that `updateBlockingState()` writes correct values to a fake `SharedPreferences`, test that `getEnforcementState()` reads correctly
- `MethodChannelHandler` — test routing logic with mock controllers
- `PermissionManager` / `VpnController` — test with mock `Activity`/`Context`

### Flutter Unit Tests

- `AppBlockerService` — inject `FakePlatformService` and in-memory `SharedPreferences`. Test activation, deactivation, reconciliation scenarios.
- `ProfileManager` — inject in-memory `SharedPreferences`. Test CRUD, persistence, migration.
- Reconciliation scenarios:
  - Flutter and Android agree — no changes
  - Android deactivated a profile (failsafe) — Flutter catches up
  - Flutter has a profile Android doesn't — Android gets cleaned up
  - Both empty — no-op

### What's NOT in Scope

- Integration tests across the method channel boundary (would require instrumented Android tests)
- UI/widget tests (existing patterns are fine)
- Changes to LockdownAccessibilityService, LockdownVpnService, FailsafeAlarmReceiver, or ServiceMonitorWorker internals

---

## 6. Risk & Ordering

This refactor must not break active blocking at any point. Ordering matters:

1. **Flutter DI first** — extract interface, inject deps. Pure refactor, no behavior change. Tests can be written immediately.
2. **MainActivity decomposition second** — extract classes, keep identical behavior. Each extraction is independently verifiable.
3. **State ownership & reconciliation last** — this is the only step that changes data flow. By this point, both sides are testable, so we can verify the new behavior thoroughly.

Each step should be a separate commit (or set of commits) that leaves the app fully functional.
