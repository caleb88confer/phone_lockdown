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
  List<String> enforcementActiveProfileIds = [];

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

  @override
  Future<Map<String, dynamic>> getEnforcementState() async {
    calls.add('getEnforcementState');
    return {
      'isBlocking': enforcementActiveProfileIds.isNotEmpty,
      'activeProfileIds': enforcementActiveProfileIds,
    };
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

  AppBlockerService createService({SharedPreferences? overridePrefs}) {
    return AppBlockerService(
      platform: fakePlatform,
      prefs: overridePrefs ?? prefs,
    );
  }

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

      final service2 = createService();
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      expect(service2.isBlocking, isTrue);
      expect(service2.activeProfileIds, contains('profile-1'));
    });

    test('restoreTimers removes expired locks', () async {
      final expiredLock = ActiveLock(
        profileId: 'expired-profile',
        lockStartTime: DateTime.now().subtract(const Duration(hours: 48)),
        failsafeMinutes: 60,
      );
      SharedPreferences.setMockInitialValues({
        'activeLocks': jsonEncode([expiredLock.toJson()]),
      });
      final freshPrefs = await SharedPreferences.getInstance();

      final service = createService(overridePrefs: freshPrefs);
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

      fakePlatform.calls.clear();

      final profiles = makeProfiles();
      await service.activateProfile(profiles[0], allProfiles: profiles);

      expect(
        fakePlatform.calls,
        contains(
          'updateBlockingState(isBlocking=true, packages=1, websites=1)',
        ),
      );
      expect(
        fakePlatform.calls,
        contains('scheduleFailsafeAlarm(profile-1)'),
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
        contains(
          'updateBlockingState(isBlocking=false, packages=0, websites=0)',
        ),
      );
      expect(
        fakePlatform.calls,
        contains('cancelFailsafeAlarm(profile-1)'),
      );
    });
  });
}
