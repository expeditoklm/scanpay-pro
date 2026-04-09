/// sales_repository.dart — v2.0
/// Enregistrement des ventes localement + synchronisation ERP via JWT.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/models/invoice.dart';
import '../core/services/external_stock_sync.dart';
import '../features/auth/auth_provider.dart';
import '../features/billing/billing_providers.dart';
import '../features/pos/cart_provider.dart';
import 'repository_providers.dart';

class SalesRepository {
  SalesRepository(this.ref);
  final Ref ref;

  Future<Invoice> checkout({
    required List<CartLine> cart,
    Uri? externalEndpoint,
  }) async {
    final auth = ref.read(authProvider);
    if (auth == null) throw Exception('Non connecté');
    if (cart.isEmpty) throw Exception('Panier vide');

    final saleId  = const Uuid().v4();
    final invRepo = ref.read(invoicesRepositoryProvider);

    final inv = await invRepo.recordSale(
      companyId:  auth.companyId,
      invoiceId:  saleId,
      lines: [for (final l in cart) (product: l.product, qty: l.quantity)],
    );
    if (inv == null) throw Exception('Stock insuffisant pour au moins une ligne.');

    // Rafraîchir la liste des ventes dans l'UI
    ref.read(salesRefreshProvider.notifier).state++;

    // Sync ERP en arrière-plan (non bloquant)
    _syncErpBackground(
      auth:   auth,
      saleId: saleId,
      cart:   cart,
    );

    return inv;
  }

  void _syncErpBackground({
    required dynamic auth,   // AuthState
    required String saleId,
    required List<CartLine> cart,
  }) {
    final sync = ref.read(externalStockSyncProvider);
    final uri  = externalEndpoint ?? erpWebhookUri;

    sync
        .sendSale(
          endpoint:    uri,
          companyId:   auth.companyId,
          saleId:      saleId,
          bearerToken: auth.accessToken,   // JWT Bearer — plus d'API Key
          lines: [
            for (final l in cart)
              ExternalSaleLine(
                productId: l.product.id,
                sku:       l.product.sku,
                quantity:  l.quantity,
              ),
          ],
        )
        .then((_) {
          // ignore: avoid_print
          print('[ERP] ✓ Vente $saleId synchronisée');
          // Rafraîchir une 2ème fois pour afficher les données ERP
          ref.read(salesRefreshProvider.notifier).state++;
        })
        .catchError((e) {
          // ignore: avoid_print
          print('[ERP] ✗ Erreur sync vente: $e');
          // La vente est déjà enregistrée localement — pas d'impact UX
        });
  }

  // Endpoint injecté lors des tests ou pour cibler un env. différent
  Uri? externalEndpoint;
}

final salesRepositoryProvider =
    Provider<SalesRepository>((ref) => SalesRepository(ref));