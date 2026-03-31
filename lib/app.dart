import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_shell.dart';

class TpeQrSaasApp extends ConsumerWidget {
  const TpeQrSaasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return MaterialApp(
      title: 'TPE QR SaaS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: auth == null ? const LoginScreen() : const HomeShell(),
    );
  }
}
