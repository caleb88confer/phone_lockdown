import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phone_lockdown/constants.dart';
import 'package:phone_lockdown/screens/dashboard_screen.dart';
import 'package:phone_lockdown/services/app_blocker_service.dart';
import 'package:phone_lockdown/services/lock_history_service.dart';
import 'package:phone_lockdown/services/master_key_service.dart';
import 'package:phone_lockdown/services/platform_channel_service.dart';
import 'package:phone_lockdown/services/unlock_state_service.dart';
import 'package:phone_lockdown/theme/app_theme.dart';

class _FakePlatformService implements PlatformChannelService {
  @override
  Future<Map<String, bool>> checkPermissions() async =>
      {'accessibility': false, 'deviceAdmin': false};
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
  Future<Map<String, dynamic>> getEnforcementState() async =>
      {'isBlocking': false, 'activeProfileIds': []};
}

const int _h = 3600 * 1000;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A fixed "today" so the seeded buckets land in a known 7-day window.
  final today = DateTime(2026, 5, 28);
  String key(int year, int month, int day) =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  Future<Widget> buildDashboard() async {
    SharedPreferences.setMockInitialValues({
      // 105h total → earns "First 24h" and "100h locked".
      kPrefMasterKeyHasInitialized: true,
      kPrefMasterKeyTotalMs: 105 * _h,
      // 25th–28th is a 4-day run (24th is a gap) → current & longest streak 4.
      kPrefLockHistoryDaily: jsonEncode({
        key(2026, 5, 22): 1 * _h,
        key(2026, 5, 23): 2 * _h,
        key(2026, 5, 25): 3 * _h,
        key(2026, 5, 26): 4 * _h,
        key(2026, 5, 27): 7 * _h, // best day this week
        key(2026, 5, 28): 2 * _h,
      }),
      kPrefLockHistorySessionCount: 12,
      kPrefLockHistoryLongestSessionMs: 7 * _h,
    });
    final prefs = await SharedPreferences.getInstance();
    final platform = _FakePlatformService();
    final appBlocker = AppBlockerService(platform: platform, prefs: prefs);
    final unlockState = UnlockStateService(prefs: prefs);
    await unlockState.init();
    final lockHistory = LockHistoryService(prefs: prefs, now: () => today);
    await lockHistory.init();
    final masterKey = MasterKeyService(
      prefs: prefs,
      appBlocker: appBlocker,
      unlockState: unlockState,
      lockHistory: lockHistory,
    );
    await masterKey.init();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<MasterKeyService>.value(value: masterKey),
        ChangeNotifierProvider<LockHistoryService>.value(value: lockHistory),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const DashboardScreen(),
      ),
    );
  }

  testWidgets('renders the hero, chart, stats and milestones at phone size',
      (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await buildDashboard());
    await tester.pumpAndSettle();

    // Hero — friendly total of 105h.
    expect(find.text('TOTAL TIME LOCKED'), findsOneWidget);
    expect(find.text('4d 9h'), findsOneWidget);
    expect(find.text('105 hours total'), findsOneWidget);

    // Sections.
    expect(find.text('THIS WEEK'), findsOneWidget);
    expect(find.text('MILESTONES'), findsOneWidget);

    // Stat grid (labels are upper-cased by the card).
    expect(find.text('CURRENT STREAK'), findsOneWidget);
    expect(find.text('4 days'), findsOneWidget);
    expect(find.text('Best: 4 days'), findsOneWidget);
    expect(find.text('LOCK SESSIONS'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);

    // Milestones — two earned (24h, 100h), two not.
    expect(find.text('First 24h'), findsOneWidget);
    expect(find.text('100h locked'), findsOneWidget);
    expect(find.text('7-day streak'), findsOneWidget);
    expect(find.text('50 sessions'), findsOneWidget);

    // No render overflow / exceptions during layout.
    expect(tester.takeException(), isNull);
  });
}
