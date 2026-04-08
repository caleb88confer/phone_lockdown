import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../models/profile.dart';
import 'platform_channel_service.dart';

class ActiveLock {
  final String profileId;
  final DateTime lockStartTime;
  final int failsafeMinutes;
  Timer? timer;

  ActiveLock({
    required this.profileId,
    required this.lockStartTime,
    required this.failsafeMinutes,
    this.timer,
  });

  Duration get remaining {
    final elapsed = DateTime.now().difference(lockStartTime);
    final total = Duration(minutes: failsafeMinutes);
    final left = total - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  bool get isExpired => remaining == Duration.zero;

  Map<String, dynamic> toJson() => {
        'profileId': profileId,
        'lockStartTime': lockStartTime.toIso8601String(),
        'failsafeMinutes': failsafeMinutes,
      };

  factory ActiveLock.fromJson(Map<String, dynamic> json) {
    return ActiveLock(
      profileId: json['profileId'] as String,
      lockStartTime: DateTime.parse(json['lockStartTime'] as String),
      failsafeMinutes: json['failsafeMinutes'] as int,
    );
  }
}

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

  /// Activates blocking for a profile. Returns null on success, or an error
  /// message string describing what went wrong.
  Future<String?> activateProfile(Profile profile, {required List<Profile> allProfiles}) async {
    if (!_isAccessibilityEnabled) {
      return 'The accessibility service is not enabled. Please enable it in Settings to block apps.';
    }

    if (profile.blockedWebsites.isNotEmpty && !_isVpnPrepared) {
      // Try to prepare VPN on the fly
      final prepared = await prepareVpn();
      if (!prepared) {
        return 'VPN permission is required to block websites. Please grant VPN permission and try again.';
      }
    }

    final lock = ActiveLock(
      profileId: profile.id,
      lockStartTime: DateTime.now(),
      failsafeMinutes: profile.failsafeMinutes,
    );

    _activeLocks[profile.id] = lock;

    // Schedule Android-side alarm FIRST — if the app crashes after this point,
    // Android will still auto-deactivate when the alarm fires.
    try {
      await _platform.scheduleFailsafeAlarm(
        profileId: profile.id,
        failsafeMillis: lock.remaining.inMilliseconds,
      );
    } catch (e) {
      debugPrint('Failed to schedule failsafe alarm: $e');
    }

    // Sync blocking state to Android, then persist Flutter state
    await _recomputeAndApply(allProfiles);
    await _saveActiveLocks();

    // Start Flutter-side timer last — if we crash before here, reconcileWithAndroid
    // will pick up the lock from Android on next startup.
    _startFailsafeTimer(lock, allProfiles);

    notifyListeners();
    return null;
  }

  /// Clean up active locks and Android-side enforcement when a profile is deleted.
  Future<void> onProfileDeleted(String profileId, {required List<Profile> allProfiles}) async {
    if (!_activeLocks.containsKey(profileId)) return;
    await deactivateProfile(profileId, allProfiles: allProfiles);
  }

  Future<bool> deactivateProfile(String profileId, {required List<Profile> allProfiles}) async {
    final lock = _activeLocks.remove(profileId);
    if (lock == null) return false;

    lock.timer?.cancel();

    // Send intent to Android first, then persist Flutter state
    await _recomputeAndApply(allProfiles);
    await _saveActiveLocks();

    // Cancel Android-side alarm
    try {
      await _platform.cancelFailsafeAlarm(profileId: profileId);
    } catch (e) {
      debugPrint('Failed to cancel failsafe alarm: $e');
    }

    notifyListeners();
    return true;
  }

  void _startFailsafeTimer(ActiveLock lock, List<Profile> allProfiles) {
    lock.timer?.cancel();
    final remaining = lock.remaining;
    if (remaining == Duration.zero) return;

    lock.timer = Timer(remaining, () async {
      _activeLocks.remove(lock.profileId);
      try {
        await _recomputeAndApply(allProfiles);
        await _saveActiveLocks();
      } catch (e) {
        // Restore the lock so Flutter state stays consistent with Android.
        // Android still enforces blocking — don't let Flutter think it's unlocked.
        _activeLocks[lock.profileId] = lock;
        debugPrint('Failsafe timer deactivation failed, lock restored: $e');
      }
      notifyListeners();
    });
  }

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

  Future<void> _loadBlockingState() async {
    final locksJson = _prefs.getString(kPrefActiveLocks);

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

    // Also handle legacy single isBlocking state
    if (_activeLocks.isEmpty) {
      final legacyBlocking = _prefs.getBool(kPrefIsBlocking) ?? false;
      if (legacyBlocking) {
        // Clear legacy state since we can't reconstruct profile info
        await _prefs.setBool(kPrefIsBlocking, false);
      }
    }

    notifyListeners();
  }

  Future<void> _saveActiveLocks() async {
    final list = _activeLocks.values.map((l) => l.toJson()).toList();
    await _prefs.setString(kPrefActiveLocks, jsonEncode(list));
    // Also maintain legacy key for Android-side compatibility
    await _prefs.setBool(kPrefIsBlocking, _activeLocks.isNotEmpty);
  }

  /// Call after app restart once profiles are available to start timers
  void restoreTimers(List<Profile> allProfiles) {
    final expiredIds = <String>[];
    for (final lock in _activeLocks.values) {
      if (lock.isExpired) {
        expiredIds.add(lock.profileId);
      } else {
        _startFailsafeTimer(lock, allProfiles);
      }
    }
    if (expiredIds.isNotEmpty) {
      for (final id in expiredIds) {
        _activeLocks.remove(id);
      }
      _saveActiveLocks();
      _recomputeAndApply(allProfiles);
      notifyListeners();
    }
  }

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
}
