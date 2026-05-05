import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/product.dart';
import '../../core/services/product_share_service.dart';
import '../../core/utils/product_image.dart';
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
  final Set<String> _selectedProductIds = <String>{};
  bool _isSharing = false;

  @override
  Widget build(BuildContext context) {
    final asyncProducts = ref.watch(productsListProvider);
    final theme = Theme.of(context);

    return asyncProducts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) {
        final isNetworkError = error.toString().contains('SocketException') ||
            error.toString().contains('ClientException') ||
            error.toString().contains('Connection') ||
            error.toString().contains('Network');

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFD7E2F2)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x120F172A),
                    blurRadius: 28,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1565D8), Color(0xFF22C1C3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Icon(
                      isNetworkError ? Icons.wifi_off_rounded : Icons.error_outline,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    isNetworkError
                        ? 'Connexion indisponible'
                        : 'Une erreur bloque les produits',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isNetworkError
                        ? 'L app n arrive pas a joindre le serveur. Si des produits existent deja en cache, ils seront recharges automatiquement.'
                        : error.toString(),
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => ref.invalidate(productsListProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Recharger'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      data: (products) {
        final pendingCount = products.where((p) => p.pendingSync).length;
        final filtered = _filterProducts(products);
        final selectionCount = _selectedProductIds.length;

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(productsListProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              _ProductsHero(
                pendingCount: pendingCount,
                query: _query,
                selectionCount: selectionCount,
                isSharing: _isSharing,
                onQueryChanged: (value) => setState(() => _query = value),
                onCreate: () => _openForm(context),
                onImport: () => _openImport(context),
                onShareSelection: selectionCount == 0
                    ? null
                    : () => _shareSelectedProducts(products),
                onClearSelection: selectionCount == 0 ? null : _clearSelection,
              ),
              const SizedBox(height: 16),
              if (products.isEmpty)
                _EmptyProductsState(
                  onCreate: () => _openForm(context),
                  onImport: () => _openImport(context),
                )
              else if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Text(
                    'Aucun produit trouve pour "$_query".',
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    selectionCount == 0
                        ? 'Appui long sur un produit pour lancer la selection.'
                        : 'Touchez pour cocher ou decocher les produits a partager.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                ...filtered.map(
                  (product) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _ProductCard(
                      product: product,
                      isSelected: _selectedProductIds.contains(product.id),
                      selectionMode: selectionCount > 0,
                      onTap: () => _handleProductTap(context, product),
                      onLongPress: () => _toggleSelection(product.id),
                    ),
                  ),
                ),
              ],
            ],
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

  Future<void> _handleProductTap(BuildContext context, Product product) async {
    if (_selectedProductIds.isNotEmpty) {
      _toggleSelection(product.id);
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailScreen(product: product),
      ),
    );
  }

  void _toggleSelection(String productId) {
    setState(() {
      if (_selectedProductIds.contains(productId)) {
        _selectedProductIds.remove(productId);
      } else {
        _selectedProductIds.add(productId);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedProductIds.clear());
  }

  Future<void> _shareSelectedProducts(List<Product> products) async {
    if (_isSharing) return;

    final selectedProducts = products
        .where((product) => _selectedProductIds.contains(product.id))
        .toList();
    if (selectedProducts.isEmpty) return;

    setState(() => _isSharing = true);
    try {
      await ProductShareService().shareProductsToWhatsApp(selectedProducts);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${selectedProducts.length} image${selectedProducts.length > 1 ? 's' : ''} prepare${selectedProducts.length > 1 ? 's' : ''} pour un seul envoi WhatsApp.',
          ),
        ),
      );
      _clearSelection();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }
}

class _ProductsHero extends StatelessWidget {
  const _ProductsHero({
    required this.pendingCount,
    required this.query,
    required this.selectionCount,
    required this.isSharing,
    required this.onQueryChanged,
    required this.onCreate,
    required this.onImport,
    required this.onShareSelection,
    required this.onClearSelection,
  });

  final int pendingCount;
  final String query;
  final int selectionCount;
  final bool isSharing;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onCreate;
  final VoidCallback onImport;
  final VoidCallback? onShareSelection;
  final VoidCallback? onClearSelection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1565D8), Color(0xFF22C1C3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220F172A),
            blurRadius: 26,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Catalogue intelligent',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Un espace produits plus propre, plus rapide et pret pour la vente moderne.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (selectionCount > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.checklist_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$selectionCount produit${selectionCount > 1 ? 's' : ''} selectionne${selectionCount > 1 ? 's' : ''}. Le partage cree une image avec la description de chaque produit en legende.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (pendingCount > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$pendingCount produit${pendingCount > 1 ? 's' : ''} en attente de synchronisation',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          TextField(
            onChanged: onQueryChanged,
            style: const TextStyle(color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Rechercher un produit, un SKU ou une description',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: Colors.white, width: 1.3),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onCreate,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0F172A),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nouveau produit'),
              ),
              OutlinedButton.icon(
                onPressed: onImport,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.32),
                  ),
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                ),
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Importer'),
              ),
              if (selectionCount > 0)
                FilledButton.icon(
                  onPressed: isSharing ? null : onShareSelection,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                  ),
                  icon: isSharing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.share_rounded),
                  label: const Text('Partager WhatsApp'),
                ),
              if (selectionCount > 0)
                OutlinedButton.icon(
                  onPressed: isSharing ? null : onClearSelection,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.32),
                    ),
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                  ),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Annuler selection'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onLongPress,
    required this.isSelected,
    required this.selectionMode,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isSelected;
  final bool selectionMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleParts = <String>[
      formatPriceEuro(product.price),
      'Stock ${product.stock}',
      if ((product.sku ?? '').trim().isNotEmpty) 'SKU ${product.sku!.trim()}',
    ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE8F7EF) : Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: isSelected ? const Color(0xFF25D366) : const Color(0xFFD7E2F2),
              width: isSelected ? 1.6 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox.expand(
                    child: buildProductImage(
                      product: product,
                      fit: BoxFit.cover,
                      fallback: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: product.pendingSync
                                ? const [Color(0xFFF59E0B), Color(0xFFF97316)]
                                : const [Color(0xFF1565D8), Color(0xFF22C1C3)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          product.name.isEmpty ? '?' : product.name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (product.pendingSync)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF4E5),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Offline',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitleParts.join(' | '),
                      style: theme.textTheme.bodySmall,
                    ),
                    if ((product.description ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        product.description!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                selectionMode
                    ? (isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded)
                    : Icons.chevron_right_rounded,
                color: selectionMode
                    ? (isSelected ? const Color(0xFF25D366) : const Color(0xFF94A3B8))
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyProductsState extends StatelessWidget {
  const _EmptyProductsState({
    required this.onCreate,
    required this.onImport,
  });

  final VoidCallback onCreate;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFD7E2F2)),
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF1565D8), Color(0xFF22C1C3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              size: 34,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Aucun produit pour le moment',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Cree ton premier produit ou importe rapidement un fichier CSV ou Excel.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Creer un produit'),
              ),
              OutlinedButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Importer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
