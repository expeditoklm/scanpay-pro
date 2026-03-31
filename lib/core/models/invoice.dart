class InvoiceLine {
  const InvoiceLine({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
  });

  final String productId;
  final String name;
  final double unitPrice;
  final int quantity;

  double get lineTotal => unitPrice * quantity;
}

class Invoice {
  const Invoice({
    required this.id,
    required this.companyId,
    required this.createdAt,
    required this.lines,
  });

  final String id;
  final String companyId;
  final DateTime createdAt;
  final List<InvoiceLine> lines;

  double get total => lines.fold<double>(0, (s, l) => s + l.lineTotal);
}
