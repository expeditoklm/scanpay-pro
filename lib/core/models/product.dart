class Product {
  const Product({
    required this.id,
    required this.companyId,
    required this.name,
    required this.price,
    required this.stock,
    this.referenceImagePath,
    this.consumerCode,
    this.referenceImageHash,
    this.description,
    this.referenceImageUrl,
    this.sku,
    this.pendingSync = false,
  });

  final String id;
  final String companyId;
  final String name;
  final double price;
  final int stock;
  final String? referenceImagePath;
  final String? consumerCode;
  final String? referenceImageHash;
  final String? description;
  final String? referenceImageUrl;
  final String? sku;
  /// true = créé/modifié hors-ligne, pas encore synchronisé avec le serveur
  final bool pendingSync;

  Product copyWith({
    String? id,
    String? companyId,
    String? name,
    double? price,
    int? stock,
    String? referenceImagePath,
    String? consumerCode,
    String? referenceImageHash,
    String? description,
    String? referenceImageUrl,
    String? sku,
    bool? pendingSync,
  }) {
    return Product(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      referenceImagePath: referenceImagePath ?? this.referenceImagePath,
      consumerCode: consumerCode ?? this.consumerCode,
      referenceImageHash: referenceImageHash ?? this.referenceImageHash,
      description: description ?? this.description,
      referenceImageUrl: referenceImageUrl ?? this.referenceImageUrl,
      sku: sku ?? this.sku,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'companyId': companyId,
        'name': name,
        'price': price,
        'stock': stock,
        'referenceImagePath': referenceImagePath,
        'consumerCode': consumerCode,
        'referenceImageHash': referenceImageHash,
        'description': description,
        'referenceImageUrl': referenceImageUrl,
        'sku': sku,
        'pendingSync': pendingSync,
      };

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      companyId: json['companyId'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      stock: (json['stock'] as num).toInt(),
      referenceImagePath: json['referenceImagePath'] as String?,
      consumerCode: json['consumerCode'] as String?,
      referenceImageHash: json['referenceImageHash'] as String?,
      description: json['description'] as String?,
      referenceImageUrl: json['referenceImageUrl'] as String?,
      sku: json['sku'] as String?,
      pendingSync: json['pendingSync'] as bool? ?? false,
    );
  }
}