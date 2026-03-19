import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile.dart';

class AppBlockerService extends ChangeNotifier {
  bool _isBlocking = false;
  bool _isAuthorized = false;

  bool get isBlocking => _isBlocking;
  bool get isAuthorized => _isAuthorized;

  AppBlockerService() {
    _loadBlockingState();
    requestAuthorization();
  }

  Future<void> requestAuthorization() async {
    // TODO: On Android, request PACKAGE_USAGE_STATS permission
    // and prompt user to enable AccessibilityService in settings.
    _isAuthorized = true;
    notifyListeners();
  }

  void toggleBlocking(Profile profile) {
    if (!_isAuthorized) {
      debugPrint('Not authorized to block apps');
      return;
    }

    _isBlocking = !_isBlocking;
    _saveBlockingState();
    _applyBlockingSettings(profile);
    notifyListeners();
  }

  void _applyBlockingSettings(Profile profile) {
    if (_isBlocking) {
      debugPrint('Blocking ${profile.blockedAppPackages.length} apps');
      // TODO: Implement Android app blocking via AccessibilityService.
      // Monitor TYPE_WINDOW_STATE_CHANGED events and overlay a blocking
      // screen when a blocked app's package name is detected in foreground.
    } else {
      debugPrint('Unblocking apps');
      // TODO: Remove blocking overlay / stop intercepting app launches.
    }
  }

  Future<void> _loadBlockingState() async {
    final prefs = await SharedPreferences.getInstance();
    _isBlocking = prefs.getBool('isBlocking') ?? false;
    notifyListeners();
  }

  Future<void> _saveBlockingState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isBlocking', _isBlocking);
  }
}
