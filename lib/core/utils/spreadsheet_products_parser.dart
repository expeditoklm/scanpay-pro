import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/product.dart';
import 'csv_products_parser.dart';

CsvProductsParserResult parseProductsSpreadsheetBytes({
  required Uint8List bytes,
  required String companyId,
  String? Function(String imageFileName)? imageFileResolver,
}) {
  final excel = Excel.decodeBytes(bytes);
  if (excel.tables.isEmpty) {
    return const CsvProductsParserResult(
      products: [],
      errors: ['Fichier Excel vide.'],
    );
  }

  final sheet = excel.tables.values.first;
  if (sheet == null || sheet.rows.isEmpty) {
    return const CsvProductsParserResult(
      products: [],
      errors: ['Fichier Excel vide.'],
    );
  }

  final header = sheet.rows.first
      .map((cell) => (cell?.value ?? '').toString().trim().toLowerCase())
      .toList();

  int idx(String name) => header.indexOf(name);

  final nameI = idx('name');
  final priceI = idx('price');
  final stockI = idx('stock');
  final skuI = idx('sku');
  final descI = idx('description');
  final imageUrlI = _findImageUrlColumn(header);
  final imageFileI = findImageFileColumn(header);

  final errors = <String>[];
  if (nameI < 0) errors.add('Colonne manquante: name');
  if (priceI < 0) errors.add('Colonne manquante: price');
  if (stockI < 0) errors.add('Colonne manquante: stock');
  if (errors.isNotEmpty) {
    return CsvProductsParserResult(products: const [], errors: errors);
  }

  final products = <Product>[];
  for (var rowIndex = 1; rowIndex < sheet.rows.length; rowIndex++) {
    final row = sheet.rows[rowIndex];

    String cellValue(int index) {
      if (index < 0 || index >= row.length) return '';
      return (row[index]?.value ?? '').toString().trim();
    }

    final name = cellValue(nameI);
    if (name.isEmpty) {
      continue;
    }

    final priceRaw = cellValue(priceI).replaceAll(',', '.');
    final stockRaw = cellValue(stockI);
    final imageUrl = imageUrlI >= 0 ? cellValue(imageUrlI) : '';
    final imageFile = imageFileI >= 0 ? cellValue(imageFileI) : '';
    final price = double.tryParse(priceRaw);
    final stock = int.tryParse(stockRaw);

    if (price == null || price < 0) {
      errors.add('Ligne ${rowIndex + 1}: price invalide ($priceRaw)');
      continue;
    }
    if (stock == null || stock < 0) {
      errors.add('Ligne ${rowIndex + 1}: stock invalide ($stockRaw)');
      continue;
    }
    if (imageUrl.isNotEmpty && !isSupportedProductImageUrl(imageUrl)) {
      errors.add(
        'Ligne ${rowIndex + 1}: image_url doit etre un lien http(s) public.',
      );
      continue;
    }
    final imagePath = resolveImportedImageFile(
      imageFile: imageFile,
      imageFileResolver: imageFileResolver,
      rowNumber: rowIndex + 1,
      errors: errors,
    );
    if (imageFile.isNotEmpty && imagePath == null) continue;

    products.add(
      Product(
        id: '',
        companyId: companyId,
        name: name,
        price: price,
        stock: stock,
        sku: skuI >= 0 ? cellValue(skuI) : null,
        description: descI >= 0 ? cellValue(descI) : null,
        referenceImageUrl: imageUrl.isEmpty ? null : imageUrl,
        referenceImagePath: imagePath,
      ),
    );
  }

  return CsvProductsParserResult(products: products, errors: errors);
}

int _findImageUrlColumn(List<String> header) {
  const aliases = ['image_url', 'image', 'image url', 'photo_url', 'photo'];
  for (final alias in aliases) {
    final index = header.indexOf(alias);
    if (index >= 0) return index;
  }
  return -1;
}
