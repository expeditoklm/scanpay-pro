import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../core/models/invoice.dart';
import '../../core/utils/price_formatter.dart';
import '../../data/sales_repository.dart';
import '../auth/auth_provider.dart';
import '../billing/billing_providers.dart';
import '../products/products_providers.dart';
import 'cart_provider.dart';
import 'invoice_pdf.dart';

class PosCartScreen extends ConsumerStatefulWidget {
  const PosCartScreen({super.key});

  @override
  ConsumerState<PosCartScreen> createState() => _PosCartScreenState();
}

class _PosCartScreenState extends ConsumerState<PosCartScreen> {
  bool _checkoutLoading = false;
  String? _error;

  Future<void> _checkout() async {
    final lines = ref.read(cartProvider);
    if (lines.isEmpty) return;

    setState(() {
      _checkoutLoading = true;
      _error = null;
    });

    try {
      final inv = await ref.read(salesRepositoryProvider).checkout(cart: lines);
      ref.read(cartProvider.notifier).clear();
      ref.invalidate(productsListProvider);
      ref.read(salesRefreshProvider.notifier).state++;
      if (!mounted) return;

      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => _InvoicePreviewScreen(invoice: inv),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _checkoutLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final total = cart.fold<double>(0, (s, l) => s + l.lineTotal);

    return Scaffold(
      appBar: AppBar(title: const Text('Panier')),
      body: Column(
        children: [
          if (_error != null)
            Material(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                title: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
              ),
            ),
          Expanded(
            child: cart.isEmpty
                ? const Center(child: Text('Panier vide'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: cart.length,
                    itemBuilder: (context, i) {
                      final line = cart[i];
                      return Card(
                        child: ListTile(
                          title: Text(line.product.name),
                          subtitle: Text('${formatPriceEuro(line.product.price)} × ${line.quantity}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove),
                                onPressed: () {
                                  ref.read(cartProvider.notifier).setQuantity(
                                        line.product.id,
                                        line.quantity - 1,
                                      );
                                },
                              ),
                              Text('${line.quantity}'),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () {
                                  if (line.quantity < line.product.stock) {
                                    ref.read(cartProvider.notifier).setQuantity(
                                          line.product.id,
                                          line.quantity + 1,
                                        );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Total : ${formatPriceEuro(total)}', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: cart.isEmpty || _checkoutLoading ? null : _checkout,
                    child: _checkoutLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Valider la vente'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoicePreviewScreen extends StatelessWidget {
  const _InvoicePreviewScreen({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Facture ${invoice.id.substring(0, 8)}…')),
      body: PdfPreview(
        build: (format) => buildInvoicePdf(invoice, format),
      ),
    );
  }
}
