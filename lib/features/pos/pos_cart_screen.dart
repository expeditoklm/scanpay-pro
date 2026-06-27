import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/invoice.dart';
import '../../core/services/xprinter_service.dart';
import '../../core/utils/price_formatter.dart';
import '../../core/utils/product_image.dart';
import '../../data/repository_providers.dart';
import '../auth/auth_provider.dart';
import '../billing/billing_providers.dart';
import '../products/products_providers.dart';
import 'cart_provider.dart';
import 'invoice_pdf.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _kBlue1  = Color(0xFF1565D8);
const _kBlue2  = Color(0xFF0D47A1);
const _kTeal   = Color(0xFF22C1C3);
const _kBg     = Color(0xFFF0F4FA);
const _kCard   = Colors.white;
const _kBorder = Color(0xFFD7E2F2);

final _receiptPreviewFormat = PdfPageFormat(
  72 * PdfPageFormat.mm,
  220 * PdfPageFormat.mm,
  marginAll: 6 * PdfPageFormat.mm,
);

class PosCartScreen extends ConsumerStatefulWidget {
  const PosCartScreen({super.key});

  @override
  ConsumerState<PosCartScreen> createState() => _PosCartScreenState();
}

class _PosCartScreenState extends ConsumerState<PosCartScreen> {
  final XPrinterService _xprinter = const XPrinterService();
  bool _checkoutLoading = false;
  String? _error;

  Future<void> _checkout() async {
    final auth = ref.read(authProvider);
    if (auth == null) return;
    final lines = ref.read(cartProvider);
    if (lines.isEmpty) return;

    setState(() {
      _checkoutLoading = true;
      _error = null;
    });

    try {
      final invRepo = ref.read(invoicesRepositoryProvider);
      final id = const Uuid().v4();
      final inv = await invRepo.recordSale(
        companyId: auth.companyId,
        invoiceId: id,
        lines: [for (final l in lines) (product: l.product, qty: l.quantity)],
      );
      if (inv == null) {
        setState(() => _error = 'Stock insuffisant pour au moins une ligne.');
        return;
      }
      ref.read(cartProvider.notifier).clear();
      ref.invalidate(productsListProvider);
      ref.read(salesRefreshProvider.notifier).state++;
      final printResult = await _xprinter.printSavedInvoice(inv);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(printResult.message),
          backgroundColor: printResult.success ? Colors.green : Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => InvoicePreviewScreen(invoice: inv)),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _checkoutLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final itemCount = cart.fold<int>(0, (s, l) => s + l.quantity);
    final total = cart.fold<double>(0, (s, l) => s + l.lineTotal);

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [

            // ── Header dégradé ─────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_kBlue2, _kBlue1, _kTeal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(8, 10, 16, 18),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shopping_cart_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Panier',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          cart.isEmpty
                              ? 'Aucun article'
                              : '$itemCount article${itemCount > 1 ? 's' : ''} — ${formatPriceEuro(total)}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.80),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (cart.isNotEmpty)
                    GestureDetector(
                      onTap: () => ref.read(cartProvider.notifier).clear(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.25)),
                        ),
                        child: const Text(
                          'Vider',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Erreur ────────────────────────────────────────────────
            if (_error != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDA4AF)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Color(0xFFE11D48), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                            color: Color(0xFFBE123C), fontSize: 13),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _error = null),
                      child: const Icon(Icons.close_rounded,
                          size: 18, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),

            // ── Liste articles ─────────────────────────────────────────
            Expanded(
              child: cart.isEmpty
                  ? _EmptyCart()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      itemCount: cart.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _CartItemCard(line: cart[index]),
                    ),
            ),

            // ── Récap + bouton valider ─────────────────────────────────
            if (cart.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  children: [
                    // Ligne sous-total items
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$itemCount article${itemCount > 1 ? 's' : ''}',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF64748B)),
                        ),
                        Text(
                          formatPriceEuro(total),
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(height: 1, color: _kBorder),
                    const SizedBox(height: 10),
                    // Total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          formatPriceEuro(total),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: _kBlue1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Bouton valider
                    GestureDetector(
                      onTap: _checkoutLoading ? null : _checkout,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: _checkoutLoading
                              ? null
                              : const LinearGradient(
                                  colors: [_kBlue2, _kBlue1, _kTeal],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                          color: _checkoutLoading
                              ? const Color(0xFFE2E8F0)
                              : null,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _checkoutLoading
                              ? null
                              : [
                                  BoxShadow(
                                    color: _kBlue1.withOpacity(0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                        ),
                        alignment: Alignment.center,
                        child: _checkoutLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: _kBlue1),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_rounded,
                                      color: Colors.white, size: 20),
                                  SizedBox(width: 10),
                                  Text(
                                    'Valider la vente',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Carte article du panier ──────────────────────────────────────────────────
class _CartItemCard extends ConsumerWidget {
  const _CartItemCard({required this.line});
  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = line.product;
    final atMax = line.quantity >= product.stock;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Image ───────────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 56,
              height: 56,
              child: buildProductImage(
                product: product,
                fit: BoxFit.cover,
                fallback: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_kBlue1, _kTeal],
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
          const SizedBox(width: 12),

          // ── Nom + prix unitaire ────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${formatPriceEuro(product.price)} / u',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 3),
                Text(
                  '= ${formatPriceEuro(line.lineTotal)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _kBlue1,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // ── Stepper quantité ───────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bouton −
                GestureDetector(
                  onTap: () => ref
                      .read(cartProvider.notifier)
                      .setQuantity(product.id, line.quantity - 1),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: line.quantity <= 1
                          ? Colors.red.withOpacity(0.08)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: line.quantity <= 1
                            ? Colors.red.withOpacity(0.20)
                            : _kBorder,
                      ),
                    ),
                    child: Icon(
                      line.quantity <= 1
                          ? Icons.delete_outline_rounded
                          : Icons.remove_rounded,
                      size: 16,
                      color: line.quantity <= 1
                          ? Colors.red
                          : const Color(0xFF475569),
                    ),
                  ),
                ),
                // Quantité
                SizedBox(
                  width: 32,
                  child: Text(
                    '${line.quantity}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                // Bouton +
                GestureDetector(
                  onTap: atMax
                      ? null
                      : () => ref
                          .read(cartProvider.notifier)
                          .setQuantity(product.id, line.quantity + 1),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: atMax
                          ? null
                          : const LinearGradient(
                              colors: [_kBlue1, _kTeal],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: atMax ? const Color(0xFFE2E8F0) : null,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: atMax
                          ? const Color(0xFF94A3B8)
                          : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Panier vide ──────────────────────────────────────────────────────────────
class _EmptyCart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _kBorder),
              ),
              child: const Icon(Icons.shopping_cart_outlined,
                  size: 36, color: Color(0xFF93C5FD)),
            ),
            const SizedBox(height: 18),
            const Text(
              'Panier vide',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Scannez un produit pour\nl\'ajouter ici.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Aperçu reçu ──────────────────────────────────────────────────────────────
class InvoicePreviewScreen extends StatelessWidget {
  const InvoicePreviewScreen({super.key, required this.invoice});
  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text('Apercu ticket'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: PdfPreview(
        initialPageFormat: _receiptPreviewFormat,
        canChangePageFormat: false,
        canDebug: false,
        build: (format) => buildInvoicePdf(invoice, format),
      ),
    );
  }
}
