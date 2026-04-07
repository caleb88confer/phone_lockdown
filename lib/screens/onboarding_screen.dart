import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/platform_channel_service.dart';
import '../services/app_blocker_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AppBlockerService>().refreshPermissions();
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingComplete', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(child: _buildStepContent()),
              const SizedBox(height: 24),
              _buildNavigation(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildWelcomeStep();
      case 1:
        return _buildProfilesStep();
      case 2:
        return _buildPermissionsStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildWelcomeStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock, size: 80, color: Colors.blue),
        const SizedBox(height: 32),
        Text(
          'Welcome to Phone Lockdown',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const Text(
          'Take control of your phone usage by blocking distracting apps and websites. '
          'Use physical QR codes or barcodes as keys to lock and unlock different profiles.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildProfilesStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.qr_code_scanner, size: 80, color: Colors.blue),
        const SizedBox(height: 32),
        Text(
          'Profiles & Unlock Codes',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const Text(
          'Create profiles for different situations — work, full day, study, etc. '
          'Each profile has its own list of blocked apps/websites, its own QR code key, '
          'and a failsafe timer that auto-unlocks after a set period.\n\n'
          'Multiple profiles can be active at the same time. '
          'Long-press a profile on the home screen to set it up.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildPermissionsStep() {
    final blocker = context.watch<AppBlockerService>();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.security, size: 80, color: Colors.blue),
        const SizedBox(height: 32),
        Text(
          'Grant Permissions',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const Text(
          'Phone Lockdown needs permissions to block apps and websites. '
          'You can grant additional permissions later from the app.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 32),
        _PermissionRow(
          label: 'Accessibility Service (App Blocking)',
          isGranted: blocker.isAccessibilityEnabled,
          onGrant: () => context.read<PlatformChannelService>().openAccessibilitySettings(),
        ),
        const SizedBox(height: 12),
        _PermissionRow(
          label: 'VPN Service (Website Blocking)',
          isGranted: blocker.isVpnPrepared,
          onGrant: () => blocker.prepareVpn(),
        ),
      ],
    );
  }

  Widget _buildNavigation() {
    final isLastStep = _currentStep == 2;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentStep > 0)
          TextButton(
            onPressed: () => setState(() => _currentStep--),
            child: const Text('Back'),
          )
        else
          const SizedBox(width: 80),
        Row(
          children: List.generate(
            3,
            (i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == _currentStep
                    ? Colors.blue
                    : Colors.grey.withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
        isLastStep
            ? ElevatedButton(
                onPressed: _completeOnboarding,
                child: const Text('Done'),
              )
            : TextButton(
                onPressed: () => setState(() => _currentStep++),
                child: const Text('Next'),
              ),
      ],
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final String label;
  final bool isGranted;
  final VoidCallback onGrant;

  const _PermissionRow({
    required this.label,
    required this.isGranted,
    required this.onGrant,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isGranted ? Icons.check_circle : Icons.error,
          color: isGranted ? Colors.green : Colors.orange,
        ),
        const SizedBox(width: 8),
        Text(label),
        const SizedBox(width: 12),
        if (!isGranted)
          ElevatedButton(
            onPressed: onGrant,
            child: const Text('Grant'),
          ),
      ],
    );
  }
}
