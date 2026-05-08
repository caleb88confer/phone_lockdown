import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../models/profile.dart';

class ProfileManager extends ChangeNotifier {
  final SharedPreferences _prefs;
  late Profile _profile;

  Profile get profile => _profile;

  /// Convenience: app_blocker_service expects a list of profiles to merge
  /// blocks across. With a single profile this is always a singleton.
  List<Profile> get profilesForBlocker => [_profile];

  ProfileManager({required SharedPreferences prefs}) : _prefs = prefs {
    _profile = Profile.defaultProfile();
    _init();
  }

  Future<void> _init() async {
    await loadProfile();
    await _migrateLegacyCode();
    notifyListeners();
  }

  Future<void> loadProfile() async {
    final saved = _prefs.getString(kPrefSavedProfiles);
    if (saved == null) {
      _profile = Profile.defaultProfile();
      await saveProfile();
      return;
    }

    // Persisted format may be a JSON list (legacy multi-profile) or a single
    // JSON object (current). Handle both.
    final trimmed = saved.trimLeft();
    if (trimmed.startsWith('[')) {
      final list = Profile.decodeList(saved);
      if (list.isEmpty) {
        _profile = Profile.defaultProfile();
      } else {
        final preferredId = _prefs.getString(kPrefCurrentProfileId);
        _profile = list.cast<Profile?>().firstWhere(
          (p) => p!.id == preferredId,
          orElse: () => list.first,
        )!;
      }
      // Collapse to single-profile storage going forward.
      await _prefs.remove(kPrefCurrentProfileId);
      await saveProfile();
    } else {
      _profile = Profile.fromJsonString(saved);
    }
  }

  Future<void> saveProfile() async {
    await _prefs.setString(kPrefSavedProfiles, _profile.toJsonString());
  }

  Profile? findProfileByCode(String code) {
    return _profile.unlockCode == code ? _profile : null;
  }

  void updateProfile({
    String? lockStyleId,
    String? lockColorId,
    String? keyStyleId,
    String? keyColorId,
    List<String>? blockedAppPackages,
    List<String>? blockedWebsites,
    String? unlockCode,
    int? failsafeMinutes,
    bool clearUnlockCode = false,
  }) {
    if (lockStyleId != null) _profile.lockStyleId = lockStyleId;
    if (lockColorId != null) _profile.lockColorId = lockColorId;
    if (keyStyleId != null) _profile.keyStyleId = keyStyleId;
    if (keyColorId != null) _profile.keyColorId = keyColorId;
    if (blockedAppPackages != null) {
      _profile.blockedAppPackages = blockedAppPackages;
    }
    if (blockedWebsites != null) {
      _profile.blockedWebsites = blockedWebsites;
    }
    if (clearUnlockCode) {
      _profile.unlockCode = null;
    } else if (unlockCode != null) {
      _profile.unlockCode = unlockCode;
    }
    if (failsafeMinutes != null) {
      _profile.failsafeMinutes = failsafeMinutes;
    }

    saveProfile();
    notifyListeners();
  }

  Future<void> _migrateLegacyCode() async {
    final legacyCode = _prefs.getString('savedCodeValue');
    if (legacyCode == null) return;
    if (_profile.unlockCode == null) {
      _profile.unlockCode = legacyCode;
      await saveProfile();
    }
    await _prefs.remove('savedCodeValue');
  }
}
