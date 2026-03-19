import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/app_blocker_service.dart';
import 'services/nfc_service.dart';
import 'services/profile_manager.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BrokeApp());
}

class BrokeApp extends StatelessWidget {
  const BrokeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppBlockerService()),
        ChangeNotifierProvider(create: (_) => ProfileManager()),
        ChangeNotifierProvider(create: (_) => NfcService()),
      ],
      child: MaterialApp(
        title: 'Broke',
        theme: AppTheme.dark,
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
