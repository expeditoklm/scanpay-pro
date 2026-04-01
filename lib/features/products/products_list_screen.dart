import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/price_formatter.dart';
import 'import_products_screen.dart';
import 'product_form_screen.dart';
import 'products_providers.dart';
import 'product_detail_screen.dart';

final _productsQueryProvider = StateProvider.autoDispose<String>((ref) => '');

class ProductsListScreen extends ConsumerWidget {
  const ProductsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(productsListProvider);
    final query = ref.watch(_productsQueryProvider);
    final q = query.trim().toLowerCase();

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (products) {
        final visible = q.isEmpty
            ? products
            : products.where((p) {
                final sku = (p.sku ?? '').toLowerCase();
                return p.name.toLowerCase().contains(q) || sku.contains(q);
              }).toList();

        if (products.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 56),
                  const SizedBox(height: 16),
                  Text('Aucun produit', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text('Créez un produit avec image de référence et QR sécurisé.'),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _openForm(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Nouveau produit'),
                  ),
                ],
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(productsListProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: visible.length + 2,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: 260,
                        child: TextField(
                          onChanged: (v) => ref.read(_productsQueryProvider.notifier).state = v,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            labelText: 'Rechercher',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(builder: (_) => const ImportProductsScreen()),
                        ),
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Importer CSV'),
                      ),
                      FilledButton.icon(
                        onPressed: () => _openForm(context, ref),
                        icon: const Icon(Icons.add),
                        label: const Text('Nouveau produit'),
                      ),
                    ],
                  ),
                );
              }
              // Footer (évite RangeError quand la liste est filtrée)
              if (i == visible.length + 1) {
                return const SizedBox(height: 24);
              }
              if (visible.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(child: Text('Aucun résultat')),
                );
              }
              final p = visible[i - 1];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?'),
                  ),
                  title: Text(p.name),
                  subtitle: Text('${formatPriceEuro(p.price)} · Stock ${p.stock}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ProductDetailScreen(product: p),
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

  Future<void> _openForm(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ProductFormScreen()),
    );
    ref.invalidate(productsListProvider);
  }
}
