import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/product.dart';
import '../../core/utils/price_formatter.dart';
import 'import_products_screen.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';
import 'products_providers.dart';

class ProductsListScreen extends ConsumerStatefulWidget {
  const ProductsListScreen({super.key});

  @override
  ConsumerState<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends ConsumerState<ProductsListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final asyncProducts = ref.watch(productsListProvider);

    return asyncProducts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erreur: $error')),
      data: (products) {
        final filtered = _filterProducts(products);

        if (products.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun produit',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Créez un produit ou importez un fichier CSV/Excel.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _openForm(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Nouveau produit'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _openImport(context),
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Importer'),
                      ),
                    ],
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
            itemCount: filtered.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'Rechercher un produit, SKU ou description',
                            ),
                            onChanged: (value) => setState(() => _query = value),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () => _openImport(context),
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Importer'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: () => _openForm(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Nouveau'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Aucun produit trouvé pour "$_query".',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                  ],
                );
              }

              final product = filtered[index - 1];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
                    ),
                  ),
                  title: Text(product.name),
                  subtitle: Text(_subtitle(product)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ProductDetailScreen(product: product),
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

  List<Product> _filterProducts(List<Product> products) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return products;
    return products.where((product) {
      return product.name.toLowerCase().contains(query) ||
          (product.sku ?? '').toLowerCase().contains(query) ||
          (product.description ?? '').toLowerCase().contains(query);
    }).toList();
  }

  String _subtitle(Product product) {
    final parts = <String>[
      formatPriceEuro(product.price),
      'Stock ${product.stock}',
    ];
    final sku = product.sku?.trim();
    if (sku != null && sku.isNotEmpty) {
      parts.add('SKU $sku');
    }
    return parts.join(' · ');
  }

  Future<void> _openForm(BuildContext context) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ProductFormScreen()),
    );
    ref.invalidate(productsListProvider);
  }

  Future<void> _openImport(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const ImportProductsScreen()),
    );
    ref.invalidate(productsListProvider);
  }
}
