import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_state.dart';

final authProvider = NotifierProvider<AuthNotifier, AuthState?>(AuthNotifier.new);

class AuthNotifier extends Notifier<AuthState?> {
  @override
  AuthState? build() => null;

  void signIn({
    required String companyId,
    required String companyName,
    required String secretKey,
  }) {
    state = AuthState(
      companyId: companyId.trim(),
      companyName: companyName.trim(),
      secretKey: secretKey,
    );
  }

  void signOut() {
    state = null;
  }
}
