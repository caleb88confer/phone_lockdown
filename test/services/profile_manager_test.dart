import 'dart:convert';
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
      final legacyPrefs = await SharedPreferences.getInstance();

      final manager = ProfileManager(prefs: legacyPrefs);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      expect(manager.profiles.first.unlockCode, 'legacy-code-123');

      expect(legacyPrefs.getString('savedCodeValue'), isNull);
    });
  });
}
