import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/price_formatter.dart';
import '../products/products_providers.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(productsListProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),

      // ── Erreur réseau : message propre + bouton réessayer ───────────────
      error: (e, _) {
        final isNetwork = e.toString().contains('SocketException') ||
            e.toString().contains('ClientException') ||
            e.toString().contains('Connection') ||
            e.toString().contains('Network');

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isNetwork ? Icons.wifi_off_rounded : Icons.error_outline,
                  size: 56,
                  color: isNetwork ? Colors.orange : Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  isNetwork ? 'Hors connexion' : 'Erreur',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  isNetwork
                      ? 'Impossible de joindre le serveur.\nAucune donnée en cache disponible.'
                      : e.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(productsListProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        );
      },

      // ── Données OK ───────────────────────────────────────────────────────
      data: (products) {
        if (products.isEmpty) {
          return const Center(
            child: Text('Aucun produit — créez-en depuis l\'onglet Produits.'),
          );
        }

        final pendingCount = products.where((p) => p.pendingSync).length;

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(productsListProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: products.length + (pendingCount > 0 ? 1 : 0),
            itemBuilder: (context, i) {
              // Bannière hors-ligne en tête de liste
              if (i == 0 && pendingCount > 0) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_upload_outlined,
                          color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$pendingCount produit${pendingCount > 1 ? 's' : ''} '
                          'en attente de synchronisation',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final p = products[pendingCount > 0 ? i - 1 : i];
              final low = p.stock <= 3;

              return Card(
                color: low
                    ? Theme.of(context)
                        .colorScheme
                        .errorContainer
                        .withValues(alpha: 0.35)
                    : null,
                child: ListTile(
                  leading: p.pendingSync
                      ? Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.orange.shade100,
                              child: Text(
                                p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                                style: TextStyle(color: Colors.orange.shade800),
                              ),
                            ),
                            Positioned(
                              right: -3,
                              top: -3,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                              ),
                            ),
                          ],
                        )
                      : null,
                  title: Text(p.name),
                  subtitle: Text(formatPriceEuro(p.price)),
                  trailing: Chip(
                    label: Text('Stock ${p.stock}'),
                    avatar: Icon(
                      low ? Icons.warning_amber : Icons.check_circle_outline,
                      size: 18,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}