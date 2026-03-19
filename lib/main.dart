import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/app_blocker_service.dart';
import 'services/profile_manager.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final onboardingComplete = prefs.getBool('onboardingComplete') ?? false;
  runApp(PhoneLockdownApp(onboardingComplete: onboardingComplete));
}

class PhoneLockdownApp extends StatelessWidget {
  final bool onboardingComplete;

  const PhoneLockdownApp({super.key, required this.onboardingComplete});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppBlockerService()),
        ChangeNotifierProvider(create: (_) => ProfileManager()),
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
