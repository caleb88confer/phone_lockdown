import 'package:flutter/services.dart';

abstract class PlatformChannelService {
  Future<List<Map<String, dynamic>>> getInstalledApps();
  Future<Map<String, bool>> checkPermissions();
  Future<void> updateBlockingState({
    required bool isBlocking,
    required List<String> blockedPackages,
    required List<String> blockedWebsites,
    List<Map<String, dynamic>>? activeProfileBlocks,
  });
  Future<void> scheduleFailsafeAlarm({
    required String profileId,
    required int failsafeMillis,
  });
  Future<void> cancelFailsafeAlarm({required String profileId});
  Future<void> openAccessibilitySettings();
  Future<void> openUsageStatsSettings();
  Future<void> requestDeviceAdmin();
  Future<bool> prepareVpn();
  Future<void> startVpn();
  Future<void> stopVpn();
  Future<bool> isVpnActive();
  Future<Map<String, dynamic>> getEnforcementState();
}

class MethodChannelPlatformService implements PlatformChannelService {
  static const _channel = MethodChannel('com.example.phone_lockdown/blocker');

  @override
  Future<List<Map<String, dynamic>>> getInstalledApps() async {
    final List<dynamic> result = await _channel.invokeMethod('getInstalledApps');
    return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<Map<String, bool>> checkPermissions() async {
    final Map<dynamic, dynamic> result =
        await _channel.invokeMethod('checkPermissions');
    return result.map((k, v) => MapEntry(k as String, v as bool));
  }

  @override
  Future<void> updateBlockingState({
    required bool isBlocking,
    required List<String> blockedPackages,
    required List<String> blockedWebsites,
    List<Map<String, dynamic>>? activeProfileBlocks,
  }) async {
    await _channel.invokeMethod('updateBlockingState', {
      'isBlocking': isBlocking,
      'blockedPackages': blockedPackages,
      'blockedWebsites': blockedWebsites,
      'activeProfileBlocks': activeProfileBlocks ?? [],
    });
  }

  @override
  Future<void> scheduleFailsafeAlarm({
    required String profileId,
    required int failsafeMillis,
  }) async {
    await _channel.invokeMethod('scheduleFailsafeAlarm', {
      'profileId': profileId,
      'failsafeMillis': failsafeMillis,
    });
  }

  @override
  Future<void> cancelFailsafeAlarm({required String profileId}) async {
    await _channel.invokeMethod('cancelFailsafeAlarm', {
      'profileId': profileId,
    });
  }

  @override
  Future<void> openAccessibilitySettings() async {
    await _channel.invokeMethod('openAccessibilitySettings');
  }

  @override
  Future<void> openUsageStatsSettings() async {
    await _channel.invokeMethod('openUsageStatsSettings');
  }

  @override
  Future<void> requestDeviceAdmin() async {
    await _channel.invokeMethod('requestDeviceAdmin');
  }

  @override
  Future<bool> prepareVpn() async {
    final result = await _channel.invokeMethod<bool>('prepareVpn');
    return result ?? false;
  }

  @override
  Future<void> startVpn() async {
    await _channel.invokeMethod('startVpn');
  }

  @override
  Future<void> stopVpn() async {
    await _channel.invokeMethod('stopVpn');
  }

  @override
  Future<bool> isVpnActive() async {
    final result = await _channel.invokeMethod<bool>('isVpnActive');
    return result ?? false;
  }

  @override
  Future<Map<String, dynamic>> getEnforcementState() async {
    final Map<dynamic, dynamic> result =
        await _channel.invokeMethod('getEnforcementState');
    return result.map((k, v) => MapEntry(k as String, v));
  }
}
