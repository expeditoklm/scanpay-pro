import 'dart:convert';

import 'package:csv/csv.dart';

import '../models/product.dart';

class CsvProductsParserResult {
  const CsvProductsParserResult({
    required this.products,
    required this.errors,
  });

  final List<Product> products;
  final List<String> errors;

  bool get isOk => errors.isEmpty;
}

/// Parse un CSV produits.
///
/// Colonnes acceptées (insensibles à la casse) :
/// - name (obligatoire)
/// - price (obligatoire)
/// - stock (obligatoire)
/// - id (optionnel)
/// - sku (optionnel)
/// - description (optionnel)
///
/// Notes:
/// - `companyId` est imposé par l’app (multi-tenant), jamais lu depuis le fichier.
/// - `price` accepte virgule ou point.
CsvProductsParserResult parseProductsCsvBytes({
  required List<int> bytes,
  required String companyId,
}) {
  final text = utf8.decode(bytes, allowMalformed: true);
  final rows = const CsvToListConverter(
    shouldParseNumbers: false,
    fieldDelimiter: ',',
  ).convert(text);

  if (rows.isEmpty) {
    return const CsvProductsParserResult(products: [], errors: ['Fichier vide.']);
  }

  final header = rows.first.map((e) => (e ?? '').toString().trim().toLowerCase()).toList();
  int idx(String name) => header.indexOf(name);

  final nameI = idx('name');
  final priceI = idx('price');
  final stockI = idx('stock');
  final idI = idx('id');
  final skuI = idx('sku');
  final descI = idx('description');

  final errors = <String>[];
  if (nameI < 0) errors.add('Colonne manquante: name');
  if (priceI < 0) errors.add('Colonne manquante: price');
  if (stockI < 0) errors.add('Colonne manquante: stock');
  if (errors.isNotEmpty) return CsvProductsParserResult(products: const [], errors: errors);

  final products = <Product>[];
  for (var r = 1; r < rows.length; r++) {
    final row = rows[r];
    String cell(int i) => (i >= 0 && i < row.length) ? (row[i] ?? '').toString().trim() : '';

    final name = cell(nameI);
    if (name.isEmpty) {
      errors.add('Ligne ${r + 1}: name vide');
      continue;
    }

    final priceRaw = cell(priceI).replaceAll(',', '.');
    final price = double.tryParse(priceRaw);
    if (price == null || price < 0) {
      errors.add('Ligne ${r + 1}: price invalide ($priceRaw)');
      continue;
    }

    final stockRaw = cell(stockI);
    final stock = int.tryParse(stockRaw);
    if (stock == null || stock < 0) {
      errors.add('Ligne ${r + 1}: stock invalide ($stockRaw)');
      continue;
    }

    products.add(
      Product(
        id: '', // Toujours vide → POST (création) même si CSV a une colonne id
        companyId: companyId,
        name: name,
        price: price,
        stock: stock,
        sku: skuI >= 0 ? cell(skuI) : null,
        description: descI >= 0 ? cell(descI) : null,
        referenceImagePath: null,
      ),
    );
  }

  return CsvProductsParserResult(products: products, errors: errors);
}

