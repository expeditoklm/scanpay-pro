import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../utils/image_hash.dart';

class SavedReferenceImage {
  const SavedReferenceImage({required this.path, required this.sha256});

  final String path;
  final String? sha256;
}

/// Persiste une image de référence dans le stockage de l’app.
///
/// Important: les chemins retournés par `image_picker` peuvent pointer vers un cache temporaire.
/// On copie donc l’image dans `ApplicationDocumentsDirectory` pour qu’elle reste disponible
/// au scan caisse plus tard.
class ProductImageService {
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

  String _safeExtension(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return '.png';
    if (p.endsWith('.webp')) return '.webp';
    return '.jpg';
  }
}

