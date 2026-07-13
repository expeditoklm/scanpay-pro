import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

import 'csv_products_parser.dart';
import 'spreadsheet_products_parser.dart';

/// Lit un ZIP contenant `produits.xlsx` (ou `produits.csv`) et `images/`.
/// Les noms de la colonne image_file sont associes aux fichiers dans images/.
Future<CsvProductsParserResult> parseProductsZipBytes({
  required Uint8List bytes,
  required String companyId,
}) async {
  final errors = <String>[];
  final archive = ZipDecoder().decodeBytes(bytes, verify: true);
  ArchiveFile? sheetFile;
  final imageFiles = <String, ArchiveFile>{};

  for (final entry in archive.files) {
    if (!entry.isFile) continue;
    final normalized = entry.name.replaceAll('\\', '/');
    final lower = normalized.toLowerCase();
    if (lower == 'produits.xlsx' || lower == 'produits.csv') {
      sheetFile ??= entry;
    }
    if (lower.startsWith('images/')) {
      final filename = normalized.split('/').last.toLowerCase();
      if (filename.isNotEmpty) imageFiles[filename] = entry;
    }
  }

  if (sheetFile == null) {
    return const CsvProductsParserResult(
      products: [],
      errors: ['Le ZIP doit contenir produits.xlsx ou produits.csv a sa racine.'],
    );
  }

  final temp = await getTemporaryDirectory();
  final extractionDir = Directory(
    '${temp.path}/quicksellpay_import_${DateTime.now().microsecondsSinceEpoch}',
  );
  await extractionDir.create(recursive: true);
  final extractedImages = <String, String>{};

  for (final entry in imageFiles.entries) {
    final originalName = entry.value.name.replaceAll('\\', '/').split('/').last;
    final output = File('${extractionDir.path}/$originalName');
    await output.writeAsBytes(entry.value.content as List<int>, flush: true);
    extractedImages[entry.key] = output.path;
  }

  String? resolveImage(String requestedName) {
    final name = requestedName.replaceAll('\\', '/').split('/').last.toLowerCase();
    return extractedImages[name];
  }

  final sheetBytes = Uint8List.fromList(sheetFile.content as List<int>);
  final result = sheetFile.name.toLowerCase().endsWith('.xlsx')
      ? parseProductsSpreadsheetBytes(
          bytes: sheetBytes,
          companyId: companyId,
          imageFileResolver: resolveImage,
        )
      : parseProductsCsvBytes(
          bytes: sheetBytes,
          companyId: companyId,
          imageFileResolver: resolveImage,
        );

  errors.addAll(result.errors);
  return CsvProductsParserResult(products: result.products, errors: errors);
}
