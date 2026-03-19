import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile.dart';

class ProfileManager extends ChangeNotifier {
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

  ProfileManager() {
    _init();
  }

  Future<void> _init() async {
    await loadProfiles();
    _ensureDefaultProfile();
    await _migrateLegacyCode();
    notifyListeners();
  }

  Future<void> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final savedProfiles = prefs.getString('savedProfiles');

    if (savedProfiles != null) {
      _profiles = Profile.decodeList(savedProfiles);
    } else {
      final defaultProfile = Profile.defaultProfile();
      _profiles = [defaultProfile];
      _currentProfileId = defaultProfile.id;
    }

    final savedId = prefs.getString('currentProfileId');
    if (savedId != null && _profiles.any((p) => p.id == savedId)) {
      _currentProfileId = savedId;
    } else {
      _currentProfileId = _profiles.first.id;
    }

    notifyListeners();
  }

  Future<void> saveProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('savedProfiles', Profile.encodeList(_profiles));
    if (_currentProfileId != null) {
      await prefs.setString('currentProfileId', _currentProfileId!);
    }
  }

  void addProfile({required String name, int? iconCodePoint}) {
    final newProfile = Profile(
      name: name,
      iconCodePoint: iconCodePoint ?? 0xe7f5,
    );
    _profiles.add(newProfile);
    _currentProfileId = newProfile.id;
    saveProfiles();
    notifyListeners();
  }

  void addProfileInstance(Profile profile) {
    _profiles.add(profile);
    _currentProfileId = profile.id;
    saveProfiles();
    notifyListeners();
  }

  void setCurrentProfile(String id) {
    if (_profiles.any((p) => p.id == id)) {
      _currentProfileId = id;
      saveProfiles();
      notifyListeners();
    }
  }

  void deleteProfile(String id) {
    _profiles.removeWhere((p) => p.id == id);
    if (_currentProfileId == id) {
      _currentProfileId = _profiles.isNotEmpty ? _profiles.first.id : null;
    }
    _ensureDefaultProfile();
    saveProfiles();
    notifyListeners();
  }

  void deleteCurrentProfile() {
    _profiles.removeWhere((p) => p.id == _currentProfileId);
    _currentProfileId = _profiles.isNotEmpty ? _profiles.first.id : null;
    _ensureDefaultProfile();
    saveProfiles();
    notifyListeners();
  }

  Profile? findProfileByCode(String code) {
    try {
      return _profiles.firstWhere((p) => p.unlockCode == code);
    } catch (_) {
      return null;
    }
  }

  void updateProfile({
    required String id,
    String? name,
    int? iconCodePoint,
    List<String>? blockedAppPackages,
    List<String>? blockedWebsites,
    String? unlockCode,
    int? failsafeMinutes,
    bool clearUnlockCode = false,
  }) {
    final index = _profiles.indexWhere((p) => p.id == id);
    if (index == -1) return;

    if (name != null) _profiles[index].name = name;
    if (iconCodePoint != null) _profiles[index].iconCodePoint = iconCodePoint;
    if (blockedAppPackages != null) {
      _profiles[index].blockedAppPackages = blockedAppPackages;
    }
    if (blockedWebsites != null) {
      _profiles[index].blockedWebsites = blockedWebsites;
    }
    if (clearUnlockCode) {
      _profiles[index].unlockCode = null;
    } else if (unlockCode != null) {
      _profiles[index].unlockCode = unlockCode;
    }
    if (failsafeMinutes != null) {
      _profiles[index].failsafeMinutes = failsafeMinutes;
    }

    saveProfiles();
    notifyListeners();
  }

  void _ensureDefaultProfile() {
    if (_profiles.isEmpty) {
      final defaultProfile = Profile.defaultProfile();
      _profiles.add(defaultProfile);
      _currentProfileId = defaultProfile.id;
    } else if (_currentProfileId == null) {
      final defaultProfile = _profiles.cast<Profile?>().firstWhere(
            (p) => p!.name == 'Default',
            orElse: () => null,
          );
      _currentProfileId = defaultProfile?.id ?? _profiles.first.id;
    }
  }

  Future<void> _migrateLegacyCode() async {
    final prefs = await SharedPreferences.getInstance();
    final legacyCode = prefs.getString('savedCodeValue');
    if (legacyCode == null) return;

    // Assign legacy code to Default profile (or first profile)
    final defaultProfile = _profiles.cast<Profile?>().firstWhere(
          (p) => p!.name == 'Default',
          orElse: () => _profiles.isNotEmpty ? _profiles.first : null,
        );
    if (defaultProfile != null && defaultProfile.unlockCode == null) {
      defaultProfile.unlockCode = legacyCode;
      await saveProfiles();
    }
    await prefs.remove('savedCodeValue');
  }
}
