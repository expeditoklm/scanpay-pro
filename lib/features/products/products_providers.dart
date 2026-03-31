import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/product.dart';
import '../../data/repository_providers.dart';
import '../auth/auth_provider.dart';

final productsListProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth == null) return [];
  final repo = ref.watch(productsRepositoryProvider);
  return repo.listProducts(auth.companyId);
});
