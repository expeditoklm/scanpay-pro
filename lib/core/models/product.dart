class Product {
  const Product({
    required this.id,
    required this.companyId,
    required this.name,
    required this.price,
    required this.stock,
    this.referenceImagePath,
  });

  final String id;
  final String companyId;
  final String name;
  final double price;
  final int stock;
  final String? referenceImagePath;

  Product copyWith({
    String? id,
    String? companyId,
    String? name,
    double? price,
    int? stock,
    String? referenceImagePath,
  }) {
    return Product(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      referenceImagePath: referenceImagePath ?? this.referenceImagePath,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'companyId': companyId,
        'name': name,
        'price': price,
        'stock': stock,
        'referenceImagePath': referenceImagePath,
      };

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      companyId: json['companyId'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      stock: (json['stock'] as num).toInt(),
      referenceImagePath: json['referenceImagePath'] as String?,
    );
  }
}
