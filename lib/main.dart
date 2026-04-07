import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/app_blocker_service.dart';
import 'services/platform_channel_service.dart';
import 'services/profile_manager.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final onboardingComplete = prefs.getBool('onboardingComplete') ?? false;
  final platform = MethodChannelPlatformService();
  runApp(PhoneLockdownApp(
    onboardingComplete: onboardingComplete,
    prefs: prefs,
    platform: platform,
  ));
}

class PhoneLockdownApp extends StatelessWidget {
  final bool onboardingComplete;
  final SharedPreferences prefs;
  final PlatformChannelService platform;

  const PhoneLockdownApp({
    super.key,
    required this.onboardingComplete,
    required this.prefs,
    required this.platform,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<PlatformChannelService>.value(value: platform),
        ChangeNotifierProvider(
          create: (_) => ProfileManager(prefs: prefs),
        ),
        ChangeNotifierProvider(
          create: (_) => AppBlockerService(platform: platform, prefs: prefs),
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
