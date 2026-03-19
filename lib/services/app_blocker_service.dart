import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  AppBlockerService() {
    _loadBlockingState();
    refreshPermissions();
  }

  Future<void> refreshPermissions() async {
    try {
      final permissions = await PlatformChannelService.checkPermissions();
      _isAccessibilityEnabled = permissions['accessibility'] ?? false;
      _isDeviceAdminEnabled = permissions['deviceAdmin'] ?? false;
      _isVpnPrepared = permissions['vpn'] ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to check permissions: $e');
    }
  }

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

    // Schedule Android-side alarm
    try {
      await PlatformChannelService.scheduleFailsafeAlarm(
        profileId: profile.id,
        failsafeMillis: lock.remaining.inMilliseconds,
      );
    } catch (e) {
      debugPrint('Failed to schedule failsafe alarm: $e');
    }

    notifyListeners();
    return true;
  }

  Future<bool> deactivateProfile(String profileId, {required List<Profile> allProfiles}) async {
    final lock = _activeLocks.remove(profileId);
    if (lock == null) return false;

    lock.timer?.cancel();

    await _saveActiveLocks();
    await _recomputeAndApply(allProfiles);

    // Cancel Android-side alarm
    try {
      await PlatformChannelService.cancelFailsafeAlarm(profileId: profileId);
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
      await _saveActiveLocks();
      await _recomputeAndApply(allProfiles);
      notifyListeners();
    });
  }

  Future<void> _recomputeAndApply(List<Profile> allProfiles) async {
    if (_activeLocks.isEmpty) {
      try {
        await PlatformChannelService.updateBlockingState(
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
      await PlatformChannelService.updateBlockingState(
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
    final prefs = await SharedPreferences.getInstance();
    final locksJson = prefs.getString('activeLocks');

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
      final legacyBlocking = prefs.getBool('isBlocking') ?? false;
      if (legacyBlocking) {
        // Clear legacy state since we can't reconstruct profile info
        await prefs.setBool('isBlocking', false);
      }
    }

    notifyListeners();
  }

  Future<void> _saveActiveLocks() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _activeLocks.values.map((l) => l.toJson()).toList();
    await prefs.setString('activeLocks', jsonEncode(list));
    // Also maintain legacy key for Android-side compatibility
    await prefs.setBool('isBlocking', _activeLocks.isNotEmpty);
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

  Future<bool> prepareVpn() async {
    try {
      final result = await PlatformChannelService.prepareVpn();
      _isVpnPrepared = result;
      notifyListeners();
      return result;
    } catch (e) {
      debugPrint('Failed to prepare VPN: $e');
      return false;
    }
  }
}
