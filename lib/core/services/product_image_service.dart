import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../utils/image_hash.dart';
import '../utils/product_image.dart';

class SavedReferenceImage {
  const SavedReferenceImage({required this.path, required this.sha256});

  final String path;
  final String? sha256;
}

class ProductImageService {
  ProductImageService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<SavedReferenceImage> persistReferenceImage({
    required String companyId,
    required String productId,
    required String sourcePath,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/reference_images/$companyId');
    if (!await dir.exists()) await dir.create(recursive: true);

    final src = File(sourcePath);
    final ext = _safeExtension(sourcePath);
    final dest = File('${dir.path}/$productId$ext');
    await dest.writeAsBytes(await src.readAsBytes());
    final hash = await sha256FileHex(dest.path);
    return SavedReferenceImage(path: dest.path, sha256: hash);
  }

  Future<SavedReferenceImage?> ensureLocalReferenceImage({
    required String companyId,
    required String productId,
    required String? localPath,
    required String? remoteUrl,
  }) async {
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (await file.exists()) {
        final hash = await sha256FileHex(file.path);
        return SavedReferenceImage(path: file.path, sha256: hash);
      }
    }

    final resolvedUrl = resolveProductImageUrl(remoteUrl);
    if (resolvedUrl == null) return null;

    final response = await _client
        .get(Uri.parse(resolvedUrl))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Téléchargement image impossible (${response.statusCode})');
    }

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/reference_images/$companyId');
    if (!await dir.exists()) await dir.create(recursive: true);

    final ext = _safeExtension(resolvedUrl);
    final dest = File('${dir.path}/$productId$ext');
    await dest.writeAsBytes(response.bodyBytes);
    final hash = await sha256FileHex(dest.path);
    return SavedReferenceImage(path: dest.path, sha256: hash);
  }

  String _safeExtension(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return '.png';
    if (p.endsWith('.webp')) return '.webp';
    if (p.endsWith('.gif')) return '.gif';
    return '.jpg';
  }
}
