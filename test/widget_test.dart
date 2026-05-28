import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phone_lockdown/main.dart';
import 'package:phone_lockdown/services/app_blocker_service.dart';
import 'package:phone_lockdown/services/lock_history_service.dart';
import 'package:phone_lockdown/services/master_key_service.dart';
import 'package:phone_lockdown/services/platform_channel_service.dart';
import 'package:phone_lockdown/services/unlock_state_service.dart';

class FakePlatformService implements PlatformChannelService {
  @override
  Future<Map<String, bool>> checkPermissions() async => {
    'accessibility': false,
    'deviceAdmin': false,
  };

  @override
  Future<void> updateBlockingState({
    required bool isBlocking,
    required List<String> blockedPackages,
    required List<String> blockedWebsites,
    List<Map<String, dynamic>>? activeProfileBlocks,
  }) async {}

  @override
  Future<void> scheduleFailsafeAlarm({
    required String profileId,
    required int failsafeMillis,
  }) async {}

  @override
  Future<void> cancelFailsafeAlarm({required String profileId}) async {}

  @override
  Future<List<Map<String, dynamic>>> getInstalledApps() async => [];

  @override
  Future<List<String>> getCustomBrowsers() async => [];

  @override
  Future<void> updateCustomBrowsers(List<String> packages) async {}

  @override
  Future<void> openAccessibilitySettings() async {}

  @override
  Future<void> openUsageStatsSettings() async {}

  @override
  Future<void> requestDeviceAdmin() async {}

  @override
  Future<Map<String, dynamic>> getEnforcementState() async => {
    'isBlocking': false,
    'activeProfileIds': [],
  };
}

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final platform = FakePlatformService();
    final appBlocker = AppBlockerService(platform: platform, prefs: prefs);
    final unlockState = UnlockStateService(prefs: prefs);
    await unlockState.init();
    final lockHistory = LockHistoryService(prefs: prefs);
    await lockHistory.init();
    final masterKey = MasterKeyService(
      prefs: prefs,
      appBlocker: appBlocker,
      unlockState: unlockState,
      lockHistory: lockHistory,
    );
    await masterKey.init();
    await tester.pumpWidget(
      PhoneLockdownApp(
        onboardingComplete: true,
        prefs: prefs,
        platform: platform,
        appBlocker: appBlocker,
        masterKey: masterKey,
        unlockState: unlockState,
        lockHistory: lockHistory,
      ),
    );
    expect(find.text('Phone Lockdown'), findsOneWidget);
  });
}
