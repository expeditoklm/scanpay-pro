import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../../core/models/product.dart';
import '../../core/services/product_share_service.dart';
import '../../core/utils/product_image.dart';
import '../../core/utils/price_formatter.dart';
import '../../core/widgets/app_loader.dart';
import '../../data/products_repository.dart';
import '../../data/repository_providers.dart';
import '../auth/auth_provider.dart';
import 'import_products_screen.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';

class ProductsListScreen extends ConsumerStatefulWidget {
  const ProductsListScreen({super.key});

  @override
  ConsumerState<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends ConsumerState<ProductsListScreen> {
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final Set<String> _selectedProductIds = <String>{};
  bool _isSharing = false;
  final List<Product> _products = <Product>[];
  Timer? _searchDebounce;
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _isRequesting = false;
  bool _hasMore = true;
  bool _showScrollTop = false;
  String? _loadError;
  String? _loadMoreError;
  int _page = 0;
  int _total = 0;
  static const _perPage = 20;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reloadProducts());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollCtrl.removeListener(_onScroll);
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncProducts = _loadError != null
        ? AsyncValue<ProductsPage>.error(_loadError!, StackTrace.current)
        : _isInitialLoading
            ? const AsyncValue<ProductsPage>.loading()
            : AsyncValue<ProductsPage>.data(ProductsPage(
                items: _products,
                page: _page,
                perPage: _perPage,
                total: _total,
                totalPages: _total == 0 ? 1 : (_total / _perPage).ceil(),
              ));

    return asyncProducts.when(
      loading: () => const AppLoader(),
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
                      isNetworkError
                          ? Icons.wifi_off_rounded
                          : Icons.error_outline,
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
                    onPressed: _reloadProducts,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Recharger'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      data: (productsPage) {
        final products = productsPage.items;
        final pendingCount = products.where((p) => p.pendingSync).length;
        final selectionCount = _selectedProductIds.length;

        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: _reloadProducts,
              child: ListView(
                controller: _scrollCtrl,
                // 88 = nav bar (78) + marge ; + bottom safe-area pour les encoche bas
                padding: EdgeInsets.fromLTRB(
                  16,
                  14,
                  16,
                  MediaQuery.of(context).padding.bottom + 88,
                ),
                children: [
                  _ProductsHero(
                    pendingCount: pendingCount,
                    query: _query,
                    searchCtrl: _searchCtrl,
                    selectionCount: selectionCount,
                    isSharing: _isSharing,
                    onQueryChanged: (value) {
                      setState(() {
                        _query = value;
                        _selectedProductIds.clear();
                      });
                      _scheduleSearch();
                    },
                    onShareSelection: selectionCount == 0
                        ? null
                        : () => _shareSelectedProducts(products),
                    onClearSelection:
                        selectionCount == 0 ? null : _clearSelection,
                  ),
                  const SizedBox(height: 16),
                  if (productsPage.total == 0 && _query.trim().isEmpty)
                    _EmptyProductsState(
                      onCreate: () => _openForm(context),
                      onImport: () => _openImport(context),
                    )
                  else if (products.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: const Color(0xFFD7E2F2)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0E0F172A),
                                blurRadius: 18,
                                offset: Offset(0, 7),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.search_off_rounded,
                                  size: 30,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Aucun résultat',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Aucun produit trouvé pour\n"$_query"',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else ...[
                    if (selectionCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          'Touchez pour cocher ou decocher les produits a partager.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ...products.map(
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
                    // ── Pied de liste : total + retour en haut ──────────────
                    _ListFooter(
                      totalCount: productsPage.total,
                      displayedCount: products.length,
                    ),
                    if (_isLoadingMore)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_loadMoreError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Center(
                          child: TextButton.icon(
                            onPressed: _loadNextPage,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text(
                                'Réessayer de charger les produits suivants'),
                          ),
                        ),
                      )
                    else if (!_hasMore && products.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 18),
                        child: Center(
                            child: Text('Tous les produits sont affichés.')),
                      ),
                  ],
                ],
              ),
            ),
            // ── FAB flottant (toujours visible) ───────────────────────
            if (_showScrollTop)
              Positioned(
                bottom: 202,
                right: 22,
                child: FloatingActionButton.small(
                  heroTag: 'products-scroll-top',
                  onPressed: () => _scrollCtrl.animateTo(
                    0,
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                  ),
                  child: const Icon(Icons.keyboard_arrow_up_rounded),
                ),
              ),
            Positioned(
              bottom: 130,
              right: 20,
              child: GestureDetector(
                onTap: () => _openForm(context),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1565D8), Color(0xFF22C1C3)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x661565D8),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openForm(BuildContext context) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ProductFormScreen()),
    );
    _reloadProducts();
  }

  Future<void> _openImport(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const ImportProductsScreen()),
    );
    _reloadProducts();
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

  void _scheduleSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _reloadProducts);
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final position = _scrollCtrl.position;
    final shouldShowTop = position.pixels > 260;
    if (shouldShowTop != _showScrollTop && mounted) {
      setState(() => _showScrollTop = shouldShowTop);
    }
    if (position.extentAfter < 280) _loadNextPage();
  }

  Future<void> _reloadProducts() async {
    if (_isRequesting) return;
    _searchDebounce?.cancel();
    if (mounted) {
      setState(() {
        _isInitialLoading = true;
        _isLoadingMore = false;
        _loadError = null;
        _loadMoreError = null;
        _page = 0;
        _total = 0;
        _hasMore = true;
        _products.clear();
      });
    }
    await _loadNextPage(initial: true);
  }

  Future<void> _loadNextPage({bool initial = false}) async {
    if (!_hasMore || _isRequesting || (!_isInitialLoading && initial)) return;
    final auth = ref.read(authProvider);
    if (auth == null) return;
    _isRequesting = true;
    if (mounted) setState(() => _isLoadingMore = !initial);
    try {
      final nextPage = _page + 1;
      final result =
          await ref.read(productsRepositoryProvider).listProductsPage(
                companyId: auth.companyId,
                page: nextPage,
                perPage: _perPage,
                query: _query,
              );
      if (!mounted) return;
      final knownIds = _products.map((product) => product.id).toSet();
      setState(() {
        _products
            .addAll(result.items.where((product) => knownIds.add(product.id)));
        _page = result.page;
        _total = result.total;
        _hasMore = result.page < result.totalPages;
        _isInitialLoading = false;
        _isLoadingMore = false;
        _isRequesting = false;
        _loadMoreError = null;
      });
      // Si l'écran est grand et que la page ne remplit pas encore la hauteur,
      // charge immédiatement la suivante sans attendre un geste de défilement.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _scrollCtrl.hasClients &&
            _scrollCtrl.position.extentAfter < 280) {
          _loadNextPage();
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isInitialLoading = false;
        _isLoadingMore = false;
        _isRequesting = false;
        if (_products.isEmpty) {
          _loadError = error.toString();
        } else {
          _loadMoreError = error.toString();
        }
      });
    }
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
            textAlign: TextAlign.center,
          ),
        ),
      );
      _clearSelection();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center),
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
    required this.searchCtrl,
    required this.selectionCount,
    required this.isSharing,
    required this.onQueryChanged,
    required this.onShareSelection,
    required this.onClearSelection,
  });

  final int pendingCount;
  final String query;
  final TextEditingController searchCtrl;
  final int selectionCount;
  final bool isSharing;
  final ValueChanged<String> onQueryChanged;
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
          const SizedBox(height: 14),
          TextField(
            controller: searchCtrl,
            onChanged: onQueryChanged,
            style: const TextStyle(color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: const Color(0xFF94A3B8),
                      tooltip: 'Effacer',
                      onPressed: () {
                        searchCtrl.clear();
                        onQueryChanged('');
                      },
                    )
                  : null,
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
          if (selectionCount > 0) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
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
                  label: const Text('Annuler'),
                ),
              ],
            ),
          ],
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
    final rawDesc = (product.description ?? '').trim();
    // Toujours 10 chars max — si vide on met un espace insécable pour garder la hauteur
    final shortDesc = rawDesc.isEmpty
        ? ' '
        : rawDesc.length > 10
            ? '${rawDesc.substring(0, 10)}…'
            : rawDesc;

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
              color: isSelected
                  ? const Color(0xFF25D366)
                  : const Color(0xFFD7E2F2),
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
              // ── Image 58×58 ─────────────────────────────────────────
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(18),
                ),
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
                          product.name.isEmpty
                              ? '?'
                              : product.name[0].toUpperCase(),
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

              // ── Texte : 3 lignes fixes → hauteur uniforme ────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ligne 1 : nom (1 ligne max)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (product.pendingSync)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF4E5),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Offline',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    // Ligne 2 : prix
                    Text(
                      formatPriceEuro(product.price),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1565D8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Ligne 3 : description tronquée (toujours présente)
                    Text(
                      shortDesc,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // ── Icône droite ─────────────────────────────────────────
              Icon(
                selectionMode
                    ? (isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded)
                    : Icons.chevron_right_rounded,
                color: selectionMode
                    ? (isSelected
                        ? const Color(0xFF25D366)
                        : const Color(0xFF94A3B8))
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

// ─── Pied de liste ────────────────────────────────────────────────────────────

class _ProductsPager extends StatelessWidget {
  const _ProductsPager({
    required this.page,
    required this.totalPages,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
            label: const Text('Précédent'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('Page $page / $totalPages'),
          ),
          FilledButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
            label: const Text('Suivant'),
          ),
        ],
      ),
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({
    required this.totalCount,
    required this.displayedCount,
  });

  final int totalCount;
  final int displayedCount;

  @override
  Widget build(BuildContext context) {
    final isFiltered = displayedCount < totalCount;
    final label = isFiltered
        ? '$displayedCount sur $totalCount produit${totalCount > 1 ? 's' : ''}'
        : '$totalCount produit${totalCount > 1 ? 's' : ''} au total';

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Column(
        children: [
          // ── Séparateur ─────────────────────────────────────────────────
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Color(0xFFD7E2F2),
                  Color(0xFFD7E2F2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Compteur total ─────────────────────────────────────────────
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 14),

          // ── Bouton retour en haut ──────────────────────────────────────
        ],
      ),
    );
  }
}
