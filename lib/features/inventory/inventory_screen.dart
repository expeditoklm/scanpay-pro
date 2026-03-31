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
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (products) {
        if (products.isEmpty) {
          return const Center(child: Text('Aucun produit — créez-en depuis l’onglet Produits.'));
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(productsListProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            itemBuilder: (context, i) {
              final p = products[i];
              final low = p.stock <= 3;
              return Card(
                color: low ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.35) : null,
                child: ListTile(
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
