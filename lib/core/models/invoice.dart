import 'dart:convert';

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

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'name': name,
        'unit_price': unitPrice,
        'quantity': quantity,
        'line_total': lineTotal,
      };
}

class Invoice {
  const Invoice({
    required this.id,
    required this.reference,
    required this.companyId,
    required this.companyName,
    required this.createdAt,
    required this.lines,
    this.customer,
    this.note,
    this.source = 'mobile_app',
  });

  final String id;
  final String reference;
  final String companyId;
  final String companyName;
  final DateTime createdAt;
  final List<InvoiceLine> lines;
  final String? customer;
  final String? note;
  final String source;

  double get total => lines.fold<double>(0, (sum, line) => sum + line.lineTotal);

  String get qrPayload => jsonEncode({
        'invoice_id': id,
        'reference': reference,
        'company_id': companyId,
        'company_name': companyName,
        'created_at': createdAt.toIso8601String(),
        'total': total,
        'source': source,
        'lines': [for (final line in lines) line.toJson()],
      });
}
