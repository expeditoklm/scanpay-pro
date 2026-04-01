class Product {
  const Product({
    required this.id,
    required this.companyId,
    required this.name,
    required this.price,
    required this.stock,
    this.sku,
    this.description,
    this.referenceImagePath,
    this.referenceImageUrl,
    this.referenceImageHash,
    this.consumerCode,
  });

  final String id;
  final String companyId;
  final String name;
  final double price;
  final int stock;
  final String? sku;
  final String? description;
  final String? referenceImagePath;
  final String? referenceImageUrl;
  final String? referenceImageHash;
  final String? consumerCode;

  Product copyWith({
    String? id,
    String? companyId,
    String? name,
    double? price,
    int? stock,
    String? sku,
    String? description,
    String? referenceImagePath,
    String? referenceImageUrl,
    String? referenceImageHash,
    String? consumerCode,
  }) {
    return Product(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      sku: sku ?? this.sku,
      description: description ?? this.description,
      referenceImagePath: referenceImagePath ?? this.referenceImagePath,
      referenceImageUrl: referenceImageUrl ?? this.referenceImageUrl,
      referenceImageHash: referenceImageHash ?? this.referenceImageHash,
      consumerCode: consumerCode ?? this.consumerCode,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'companyId': companyId,
        'name': name,
        'price': price,
        'stock': stock,
        'sku': sku,
        'description': description,
        'referenceImagePath': referenceImagePath,
        'referenceImageUrl': referenceImageUrl,
        'referenceImageHash': referenceImageHash,
        'consumerCode': consumerCode,
      };

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      companyId: json['companyId'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      stock: (json['stock'] as num).toInt(),
      sku: json['sku'] as String?,
      description: json['description'] as String?,
      referenceImagePath: json['referenceImagePath'] as String?,
      referenceImageUrl: json['referenceImageUrl'] as String?,
      referenceImageHash: json['referenceImageHash'] as String?,
      consumerCode: json['consumerCode'] as String?,
    );
  }
}
