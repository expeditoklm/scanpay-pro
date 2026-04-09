import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/invoice.dart';
import '../../data/repository_providers.dart';
import '../auth/auth_provider.dart';

final salesRefreshProvider = StateProvider<int>((ref) => 0);

final invoicesListProvider = FutureProvider.autoDispose<List<Invoice>>((ref) async {
  ref.watch(salesRefreshProvider);
  final auth = ref.watch(authProvider);
  if (auth == null) return const [];
  return ref.watch(invoicesRepositoryProvider).listForCompany(auth.companyId);
});
