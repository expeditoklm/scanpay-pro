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
    this.pendingSync = false,
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
  final bool pendingSync;

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'reference': reference,
        'company_id': companyId,
        'company_name': companyName,
        'created_at': createdAt.toIso8601String(),
        'customer': customer,
        'note': note,
        'source': source,
        'pending_sync': pendingSync,
        'lines': [for (final line in lines) line.toJson()],
      };

  factory Invoice.fromJson(Map<String, dynamic> json) {
    final rawLines = (json['lines'] as List<dynamic>? ?? const []);
    return Invoice(
      id: json['id'] as String? ?? '',
      reference: json['reference'] as String? ?? '',
      companyId: json['company_id'] as String? ?? '',
      companyName: json['company_name'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      customer: json['customer'] as String?,
      note: json['note'] as String?,
      source: json['source'] as String? ?? 'mobile_app',
      pendingSync: json['pending_sync'] as bool? ?? false,
      lines: rawLines.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return InvoiceLine(
          productId: map['product_id'] as String? ?? '',
          name: map['name'] as String? ?? 'Produit',
          unitPrice: (map['unit_price'] as num? ?? 0).toDouble(),
          quantity: (map['quantity'] as num? ?? 0).toInt(),
        );
      }).toList(),
    );
  }

  Invoice copyWith({
    String? id,
    String? reference,
    String? companyId,
    String? companyName,
    DateTime? createdAt,
    List<InvoiceLine>? lines,
    String? customer,
    String? note,
    String? source,
    bool? pendingSync,
  }) {
    return Invoice(
      id: id ?? this.id,
      reference: reference ?? this.reference,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      createdAt: createdAt ?? this.createdAt,
      lines: lines ?? this.lines,
      customer: customer ?? this.customer,
      note: note ?? this.note,
      source: source ?? this.source,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }
}
