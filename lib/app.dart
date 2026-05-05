import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_shell.dart';
import 'features/onboarding/onboarding_screen.dart';

const kOnboardingSeenStorageKey = 'onboarding_seen_v1';

class TpeQrSaasApp extends ConsumerStatefulWidget {
  const TpeQrSaasApp({
    super.key,
    required this.initialOnboardingSeen,
  });

  final bool initialOnboardingSeen;

  @override
  ConsumerState<TpeQrSaasApp> createState() => _TpeQrSaasAppState();
}

class _TpeQrSaasAppState extends ConsumerState<TpeQrSaasApp> {
  late bool _onboardingSeen = widget.initialOnboardingSeen;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final home = auth != null
        ? const HomeShell()
        : (_onboardingSeen
            ? const LoginScreen()
            : OnboardingScreen(
                onCompleted: _completeOnboarding,
              ));

    return MaterialApp(
      title: 'TPE QR SaaS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: home,
    );
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kOnboardingSeenStorageKey, true);
    if (!mounted) return;
    setState(() => _onboardingSeen = true);
  }
}
