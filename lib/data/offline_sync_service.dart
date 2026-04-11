import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_provider.dart';
import '../features/billing/billing_providers.dart';
import '../features/products/products_providers.dart';
import 'repository_providers.dart';

class OfflineSyncService {
  OfflineSyncService(this.ref);

  final Ref ref;
  bool _running = false;

  Future<void> syncCurrentCompany() async {
    if (_running) return;
    final auth = ref.read(authProvider);
    if (auth == null) return;

    _running = true;
    try {
      final productsRepo = ref.read(erpProductsRepositoryProvider);
      final invoicesRepo = ref.read(invoicesRepositoryProvider);
      await productsRepo.syncPendingChanges(auth.companyId);
      await invoicesRepo.syncPendingSales(auth.companyId);
      ref.invalidate(productsListProvider);
      ref.read(salesRefreshProvider.notifier).state++;
    } finally {
      _running = false;
    }
  }
}

final offlineSyncProvider = Provider<OfflineSyncService>((ref) {
  return OfflineSyncService(ref);
});
