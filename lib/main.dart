import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'features/auth/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final initialAuth =
      AuthNotifier.decodeStoredState(prefs.getString(kAuthStorageKey));
  runApp(
    ProviderScope(
      overrides: [
        initialAuthStateProvider.overrideWithValue(initialAuth),
      ],
      child: const TpeQrSaasApp(),
    ),
  );
}
