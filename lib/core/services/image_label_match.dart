import 'dart:io';

import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

/// Compare deux images via les libellés ML Kit (anti-fraude étiquette / produit).
/// Retourne un score entre 0 et 1 (recouvrement des libellés normalisés).
class ImageLabelMatch {
  ImageLabelMatch._();

  static Future<double> similarityScore(String imagePathA, String imagePathB) async {
    final fileA = File(imagePathA);
    final fileB = File(imagePathB);
    if (!await fileA.exists() || !await fileB.exists()) return 0;

    final labeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.4));
    try {
      final labelsA = await labeler.processImage(InputImage.fromFilePath(imagePathA));
      final labelsB = await labeler.processImage(InputImage.fromFilePath(imagePathB));
      final setA = labelsA.map((e) => e.label.toLowerCase().trim()).toSet();
      final setB = labelsB.map((e) => e.label.toLowerCase().trim()).toSet();
      if (setA.isEmpty && setB.isEmpty) return 0.3;
      final inter = setA.intersection(setB).length;
      final union = setA.union(setB).length;
      if (union == 0) return 0;
      return inter / union;
    } finally {
      await labeler.close();
    }
  }
}
