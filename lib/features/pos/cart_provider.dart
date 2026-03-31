import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/product.dart';

class CartLine {
  const CartLine({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  double get lineTotal => product.price * quantity;

  CartLine copyWith({Product? product, int? quantity}) {
    return CartLine(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}

final cartProvider = NotifierProvider<CartNotifier, List<CartLine>>(CartNotifier.new);

class CartNotifier extends Notifier<List<CartLine>> {
  @override
  List<CartLine> build() => [];

  void addProduct(Product product, {int quantity = 1}) {
    final list = [...state];
    final i = list.indexWhere((l) => l.product.id == product.id);
    if (i >= 0) {
      list[i] = list[i].copyWith(quantity: list[i].quantity + quantity);
    } else {
      list.add(CartLine(product: product, quantity: quantity));
    }
    state = list;
  }

  void setQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeLine(productId);
      return;
    }
    state = [
      for (final line in state)
        if (line.product.id == productId) line.copyWith(quantity: quantity) else line,
    ];
  }

  void removeLine(String productId) {
    state = state.where((l) => l.product.id != productId).toList();
  }

  void clear() {
    state = [];
  }

  double get total => state.fold<double>(0, (s, l) => s + l.lineTotal);
}
