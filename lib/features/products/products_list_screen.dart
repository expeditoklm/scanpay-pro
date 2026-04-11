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
      // ── Chargement ────────────────────────────────────────────────────────
      loading: () => const Center(child: CircularProgressIndicator()),

      // ── Erreur réseau : on retente depuis le cache ─────────────────────
      error: (error, stack) {
        final isNetworkError = error.toString().contains('SocketException') ||
            error.toString().contains('ClientException') ||
            error.toString().contains('Connection') ||
            error.toString().contains('Network');

        if (isNetworkError) {
          // Relancer silencieusement depuis le cache persisté
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.invalidate(productsListProvider);
          });
        }

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isNetworkError ? Icons.wifi_off_rounded : Icons.error_outline,
                  size: 56,
                  color: isNetworkError
                      ? Colors.orange
                      : Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  isNetworkError
                      ? 'Hors connexion'
                      : 'Une erreur est survenue',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  isNetworkError
                      ? 'Impossible de joindre le serveur.\nVos données locales sont affichées.'
                      : error.toString(),
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

      // ── Données OK ────────────────────────────────────────────────────────
      data: (products) {
        final pendingCount = products.where((p) => p.pendingSync).length;
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Bannière hors-ligne ──────────────────────────────
                    if (pendingCount > 0)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
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
                      ),
                    // ── Barre recherche + boutons ────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText:
                                  'Rechercher un produit, SKU ou description',
                            ),
                            onChanged: (value) =>
                                setState(() => _query = value),
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
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        backgroundColor: product.pendingSync
                            ? Colors.orange.shade100
                            : null,
                        child: Text(
                          product.name.isNotEmpty
                              ? product.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: product.pendingSync
                                ? Colors.orange.shade800
                                : null,
                          ),
                        ),
                      ),
                      // ── Badge hors-ligne ────────────────────────────
                      if (product.pendingSync)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 1.5),
                            ),
                            child: const Icon(
                              Icons.cloud_upload,
                              size: 8,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(product.name)),
                      if (product.pendingSync)
                        Tooltip(
                          message: 'Non synchronisé — sera envoyé dès la reconnexion',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Hors ligne',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
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