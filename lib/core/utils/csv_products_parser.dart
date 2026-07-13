import 'dart:convert';

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

CsvProductsParserResult parseProductsCsvBytes({
  required List<int> bytes,
  required String companyId,
  String? Function(String imageFileName)? imageFileResolver,
}) {
  final text = utf8.decode(bytes, allowMalformed: true);
  final rows = _parseCsvRows(text);

  if (rows.isEmpty) {
    return const CsvProductsParserResult(
      products: [],
      errors: ['Fichier vide.'],
    );
  }

  final header = rows.first
      .map((value) => value.trim().toLowerCase())
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
  for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
    final row = rows[rowIndex];

    String cell(int index) {
      if (index < 0 || index >= row.length) return '';
      return row[index].trim();
    }

    final name = cell(nameI);
    if (name.isEmpty) {
      continue;
    }

    final priceRaw = cell(priceI).replaceAll(',', '.');
    final stockRaw = cell(stockI);
    final imageUrl = imageUrlI >= 0 ? cell(imageUrlI) : '';
    final imageFile = imageFileI >= 0 ? cell(imageFileI) : '';
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
        sku: skuI >= 0 ? cell(skuI) : null,
        description: descI >= 0 ? cell(descI) : null,
        referenceImageUrl: imageUrl.isEmpty ? null : imageUrl,
        referenceImagePath: imagePath,
      ),
    );
  }

  return CsvProductsParserResult(products: products, errors: errors);
}

/// Une image importee est un lien public direct (https://...) accessible
/// depuis l'application et la page de verification client.
bool isSupportedProductImageUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
      uri.hasAuthority &&
      (uri.scheme == 'https' || uri.scheme == 'http');
}

int _findImageUrlColumn(List<String> header) {
  const aliases = ['image_url', 'image', 'image url', 'photo_url', 'photo'];
  for (final alias in aliases) {
    final index = header.indexOf(alias);
    if (index >= 0) return index;
  }
  return -1;
}

int findImageFileColumn(List<String> header) {
  const aliases = ['image_file', 'image file', 'photo_file', 'photo file'];
  for (final alias in aliases) {
    final index = header.indexOf(alias);
    if (index >= 0) return index;
  }
  return -1;
}

String? resolveImportedImageFile({
  required String imageFile,
  required String? Function(String imageFileName)? imageFileResolver,
  required int rowNumber,
  required List<String> errors,
}) {
  if (imageFile.isEmpty) return null;
  if (imageFileResolver == null) {
    errors.add('Ligne $rowNumber: image_file est disponible uniquement dans un fichier ZIP.');
    return null;
  }
  final path = imageFileResolver(imageFile);
  if (path == null) {
    errors.add('Ligne $rowNumber: image introuvable dans images/ ($imageFile).');
  }
  return path;
}

List<List<String>> _parseCsvRows(String source) {
  final rows = <List<String>>[];
  final currentRow = <String>[];
  final currentCell = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < source.length; i++) {
    final char = source[i];

    if (char == '"') {
      final nextIsQuote = i + 1 < source.length && source[i + 1] == '"';
      if (inQuotes && nextIsQuote) {
        currentCell.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }

    if (!inQuotes && char == ',') {
      currentRow.add(currentCell.toString());
      currentCell.clear();
      continue;
    }

    if (!inQuotes && (char == '\n' || char == '\r')) {
      if (char == '\r' && i + 1 < source.length && source[i + 1] == '\n') {
        i++;
      }
      currentRow.add(currentCell.toString());
      currentCell.clear();
      if (currentRow.any((cell) => cell.trim().isNotEmpty)) {
        rows.add(List<String>.from(currentRow));
      }
      currentRow.clear();
      continue;
    }

    currentCell.write(char);
  }

  currentRow.add(currentCell.toString());
  if (currentRow.any((cell) => cell.trim().isNotEmpty)) {
    rows.add(List<String>.from(currentRow));
  }

  return rows;
}
