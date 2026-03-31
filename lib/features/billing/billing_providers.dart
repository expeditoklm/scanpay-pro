import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/invoice.dart';
import '../../data/repository_providers.dart';
import '../auth/auth_provider.dart';

/// Incrémenter après une vente pour rafraîchir la liste des factures.
final salesRefreshProvider = StateProvider<int>((ref) => 0);

final invoicesListProvider = Provider.autoDispose<List<Invoice>>((ref) {
  ref.watch(salesRefreshProvider);
  final auth = ref.watch(authProvider);
  if (auth == null) return [];
  return ref.watch(invoicesRepositoryProvider).listForCompany(auth.companyId);
});
