import 'package:flutter/services.dart';

class PlatformChannelService {
  static const _channel = MethodChannel('com.example.phone_lockdown/blocker');

  static Future<List<Map<String, dynamic>>> getInstalledApps() async {
    final List<dynamic> result = await _channel.invokeMethod('getInstalledApps');
    return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, bool>> checkPermissions() async {
    final Map<dynamic, dynamic> result =
        await _channel.invokeMethod('checkPermissions');
    return result.map((k, v) => MapEntry(k as String, v as bool));
  }

  static Future<void> updateBlockingState({
    required bool isBlocking,
    required List<String> blockedPackages,
    required List<String> blockedWebsites,
  }) async {
    await _channel.invokeMethod('updateBlockingState', {
      'isBlocking': isBlocking,
      'blockedPackages': blockedPackages,
      'blockedWebsites': blockedWebsites,
    });
  }

  static Future<void> openAccessibilitySettings() async {
    await _channel.invokeMethod('openAccessibilitySettings');
  }

  static Future<void> openUsageStatsSettings() async {
    await _channel.invokeMethod('openUsageStatsSettings');
  }

  static Future<void> requestDeviceAdmin() async {
    await _channel.invokeMethod('requestDeviceAdmin');
  }

  static Future<bool> prepareVpn() async {
    final result = await _channel.invokeMethod<bool>('prepareVpn');
    return result ?? false;
  }

  static Future<void> startVpn() async {
    await _channel.invokeMethod('startVpn');
  }

  static Future<void> stopVpn() async {
    await _channel.invokeMethod('stopVpn');
  }

  static Future<bool> isVpnActive() async {
    final result = await _channel.invokeMethod<bool>('isVpnActive');
    return result ?? false;
  }
}
