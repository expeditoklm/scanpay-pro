import '../core/models/invoice.dart';
import '../core/models/product.dart';
import 'products_repository.dart';

class InvoicesRepository {
  InvoicesRepository(this._products);

  final ProductsRepository _products;
  final List<Invoice> _invoices = [];

  List<Invoice> listForCompany(String companyId) =>
      _invoices.where((i) => i.companyId == companyId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<Invoice?> recordSale({
    required String companyId,
    required String invoiceId,
    required List<({Product product, int qty})> lines,
  }) async {
    for (final line in lines) {
      final ok = await _products.decrementStock(companyId, line.product.id, line.qty);
      if (ok == null) return null;
    }
    final inv = Invoice(
      id: invoiceId,
      companyId: companyId,
      createdAt: DateTime.now(),
      lines: [
        for (final l in lines)
          InvoiceLine(
            productId: l.product.id,
            name: l.product.name,
            unitPrice: l.product.price,
            quantity: l.qty,
          ),
      ],
    );
    _invoices.add(inv);
    return inv;
  }
}
