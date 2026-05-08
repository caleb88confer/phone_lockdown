import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phone_lockdown/constants.dart';
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
    test('toJsonString and fromJsonString are inverses', () {
      final profile = Profile(
        id: 'test-id-1',
        name: 'Default',
        blockedAppPackages: ['com.twitter.android'],
        blockedWebsites: ['twitter.com'],
        unlockCode: 'abc123',
        failsafeMinutes: 60,
      );

      final encoded = profile.toJsonString();
      final decoded = Profile.fromJsonString(encoded);

      expect(decoded.id, 'test-id-1');
      expect(decoded.blockedAppPackages, ['com.twitter.android']);
      expect(decoded.blockedWebsites, ['twitter.com']);
      expect(decoded.unlockCode, 'abc123');
      expect(decoded.failsafeMinutes, 60);
    });

    test('Profile.fromJson uses default failsafeMinutes when missing', () {
      final json = {
        'id': 'test-id',
        'name': 'Default',
        'blockedAppPackages': <String>[],
        'blockedWebsites': <String>[],
      };
      final profile = Profile.fromJson(json);
      expect(profile.failsafeMinutes, 1440);
    });
  });

  group('ProfileManager single-profile model', () {
    test('starts with default profile when no saved data', () async {
      final manager = ProfileManager(prefs: prefs);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      expect(manager.profile.name, 'Default');
      expect(manager.profilesForBlocker, hasLength(1));
    });

    test('updateProfile mutates fields and persists', () async {
      final manager = ProfileManager(prefs: prefs);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      manager.updateProfile(
        blockedAppPackages: ['com.test.app'],
        blockedWebsites: ['test.com'],
        failsafeMinutes: 30,
      );

      expect(manager.profile.blockedAppPackages, ['com.test.app']);
      expect(manager.profile.blockedWebsites, ['test.com']);
      expect(manager.profile.failsafeMinutes, 30);

      // Reload to verify persistence.
      final reloaded = ProfileManager(prefs: prefs);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);
      expect(reloaded.profile.blockedAppPackages, ['com.test.app']);
      expect(reloaded.profile.failsafeMinutes, 30);
    });

    test('findProfileByCode returns match', () async {
      final manager = ProfileManager(prefs: prefs);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      manager.updateProfile(unlockCode: 'secret-code');

      expect(manager.findProfileByCode('secret-code'), isNotNull);
      expect(manager.findProfileByCode('non-existent'), isNull);
    });

    test('collapses legacy multi-profile list to single profile', () async {
      // Simulate persisted state from the previous multi-profile system.
      SharedPreferences.setMockInitialValues({
        kPrefSavedProfiles:
            '[{"id":"a","name":"Default","lockStyleId":"small_sturdy","lockColorId":"grey","keyStyleId":"key_4","keyColorId":"gold","blockedAppPackages":[],"blockedWebsites":[],"unlockCode":null,"failsafeMinutes":1440},'
            '{"id":"b","name":"Work","lockStyleId":"small_sturdy","lockColorId":"grey","keyStyleId":"key_4","keyColorId":"gold","blockedAppPackages":["com.work"],"blockedWebsites":[],"unlockCode":"work-code","failsafeMinutes":60}]',
        kPrefCurrentProfileId: 'b',
      });
      final legacyPrefs = await SharedPreferences.getInstance();

      final manager = ProfileManager(prefs: legacyPrefs);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      // Currently-selected legacy profile is preserved.
      expect(manager.profile.id, 'b');
      expect(manager.profile.unlockCode, 'work-code');
      // Legacy current-id key cleared, storage now single-profile JSON.
      expect(legacyPrefs.getString(kPrefCurrentProfileId), isNull);
      final saved = legacyPrefs.getString(kPrefSavedProfiles);
      expect(saved, isNotNull);
      expect(saved!.trimLeft().startsWith('{'), isTrue);
    });
  });

  group('ProfileManager legacy migration', () {
    test('migrates savedCodeValue to profile unlockCode', () async {
      SharedPreferences.setMockInitialValues({
        'savedCodeValue': 'legacy-code-123',
      });
      final legacyPrefs = await SharedPreferences.getInstance();

      final manager = ProfileManager(prefs: legacyPrefs);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      expect(manager.profile.unlockCode, 'legacy-code-123');
      expect(legacyPrefs.getString('savedCodeValue'), isNull);
    });
  });
}
