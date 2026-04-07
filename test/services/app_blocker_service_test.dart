import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phone_lockdown/models/profile.dart';
import 'package:phone_lockdown/services/app_blocker_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.example.phone_lockdown/blocker'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'checkPermissions':
            return {
              'accessibility': true,
              'deviceAdmin': true,
              'vpn': true,
            };
          case 'updateBlockingState':
            return null;
          case 'scheduleFailsafeAlarm':
            return null;
          case 'cancelFailsafeAlarm':
            return null;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.example.phone_lockdown/blocker'),
      null,
    );
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
      final service = AppBlockerService();
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
      final service = AppBlockerService();
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
      final service = AppBlockerService();
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
      final service = AppBlockerService();
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
      final service1 = AppBlockerService();
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      final profiles = makeProfiles();
      await service1.activateProfile(profiles[0], allProfiles: profiles);

      final service2 = AppBlockerService();
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

      final service = AppBlockerService();
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      expect(service.isBlocking, isFalse);
    });
  });
}
