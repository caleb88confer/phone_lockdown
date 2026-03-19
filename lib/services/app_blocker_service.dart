import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile.dart';
import 'platform_channel_service.dart';

class AppBlockerService extends ChangeNotifier {
  bool _isBlocking = false;
  bool _isAccessibilityEnabled = false;
  bool _isDeviceAdminEnabled = false;
  bool _isVpnPrepared = false;

  bool get isBlocking => _isBlocking;
  bool get isAccessibilityEnabled => _isAccessibilityEnabled;
  bool get isDeviceAdminEnabled => _isDeviceAdminEnabled;
  bool get isVpnPrepared => _isVpnPrepared;

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

  Future<bool> toggleBlocking(Profile profile) async {
    if (!_isAccessibilityEnabled) {
      debugPrint('Accessibility service not enabled');
      return false;
    }

    _isBlocking = !_isBlocking;
    _saveBlockingState();
    await _applyBlockingSettings(profile);
    notifyListeners();
    return true;
  }

  Future<void> _applyBlockingSettings(Profile profile) async {
    try {
      await PlatformChannelService.updateBlockingState(
        isBlocking: _isBlocking,
        blockedPackages: profile.blockedAppPackages,
        blockedWebsites: profile.blockedWebsites,
      );
    } catch (e) {
      debugPrint('Failed to update blocking state: $e');
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
