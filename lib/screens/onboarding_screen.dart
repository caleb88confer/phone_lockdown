import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/platform_channel_service.dart';
import '../services/app_blocker_service.dart';
import '../theme/app_colors.dart';
import '../theme/bevel.dart';

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
      backgroundColor: AppColors.surface,
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
        Icon(Icons.lock, size: 80, color: AppColors.primaryContainer),
        const SizedBox(height: 32),
        Text(
          'Welcome to Phone Lockdown',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Take control of your phone usage by blocking distracting apps and websites. '
          'Use physical QR codes or barcodes as keys to lock and unlock different profiles.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildProfilesStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.qr_code_scanner, size: 80, color: AppColors.primaryContainer),
        const SizedBox(height: 32),
        Text(
          'Profiles & Unlock Codes',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Create profiles for different situations — work, full day, study, etc. '
          'Each profile has its own list of blocked apps/websites, its own QR code key, '
          'and a failsafe timer that auto-unlocks after a set period.\n\n'
          'Multiple profiles can be active at the same time. '
          'Tap a profile on the home screen to set it up.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildPermissionsStep() {
    final blocker = context.watch<AppBlockerService>();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.security, size: 80, color: AppColors.primaryContainer),
        const SizedBox(height: 32),
        Text(
          'Grant Permissions',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Phone Lockdown needs permissions to block apps and websites. '
          'You can grant additional permissions later from the app.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 32),
        _PermissionRow(
          label: 'Accessibility Service (App & Website Blocking)',
          isGranted: blocker.isAccessibilityEnabled,
          onGrant: () => context.read<PlatformChannelService>().openAccessibilitySettings(),
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
            child: const Text('BACK'),
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
                color: i == _currentStep
                    ? AppColors.primaryContainer
                    : AppColors.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
        isLastStep
            ? Container(
                decoration: Bevel.raised(fill: AppColors.primaryContainer),
                child: TextButton(
                  onPressed: _completeOnboarding,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.onPrimaryContainer,
                  ),
                  child: const Text(
                    'DONE',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              )
            : TextButton(
                onPressed: () => setState(() => _currentStep++),
                child: const Text('NEXT'),
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
          color: isGranted ? const Color(0xFF2E7D32) : AppColors.primaryContainer,
        ),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(width: 12),
        if (!isGranted)
          Container(
            decoration: Bevel.raised(fill: AppColors.primaryContainer),
            child: TextButton(
              onPressed: onGrant,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.onPrimaryContainer,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'GRANT',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
