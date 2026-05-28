import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/app_blocker_service.dart';
import 'services/explosion_settings.dart';
import 'services/lock_history_service.dart';
import 'services/master_key_service.dart';
import 'services/platform_channel_service.dart';
import 'services/profile_manager.dart';
import 'services/unlock_state_service.dart';
import 'services/unlocked_items_service.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final onboardingComplete = prefs.getBool('onboardingComplete') ?? false;
  final platform = MethodChannelPlatformService();
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
  runApp(
    PhoneLockdownApp(
      onboardingComplete: onboardingComplete,
      prefs: prefs,
      platform: platform,
      appBlocker: appBlocker,
      masterKey: masterKey,
      unlockState: unlockState,
      lockHistory: lockHistory,
    ),
  );
}

class PhoneLockdownApp extends StatelessWidget {
  final bool onboardingComplete;
  final SharedPreferences prefs;
  final PlatformChannelService platform;
  final AppBlockerService appBlocker;
  final MasterKeyService masterKey;
  final UnlockStateService unlockState;
  final LockHistoryService lockHistory;

  const PhoneLockdownApp({
    super.key,
    required this.onboardingComplete,
    required this.prefs,
    required this.platform,
    required this.appBlocker,
    required this.masterKey,
    required this.unlockState,
    required this.lockHistory,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<PlatformChannelService>.value(value: platform),
        ChangeNotifierProvider(create: (_) => ProfileManager(prefs: prefs)),
        ChangeNotifierProvider<AppBlockerService>.value(value: appBlocker),
        ChangeNotifierProvider<MasterKeyService>.value(value: masterKey),
        ChangeNotifierProvider<UnlockStateService>.value(value: unlockState),
        ChangeNotifierProvider<LockHistoryService>.value(value: lockHistory),
        ChangeNotifierProvider(create: (_) => ExplosionSettings(prefs: prefs)),
        ChangeNotifierProvider(
          create: (_) => UnlockedItemsService(unlockState: unlockState),
        ),
      ],
      child: MaterialApp(
        title: 'Phone Lockdown',
        theme: AppTheme.dark,
        initialRoute: onboardingComplete ? '/home' : '/onboarding',
        routes: {
          '/home': (_) => const HomeScreen(),
          '/onboarding': (_) => const OnboardingScreen(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
