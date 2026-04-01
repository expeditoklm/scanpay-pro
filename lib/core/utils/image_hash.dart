import 'dart:io';

import 'package:crypto/crypto.dart';

/// Hash SHA256 d'un fichier image pour lier QR ↔ image de référence.
Future<String?> sha256FileHex(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  final bytes = await file.readAsBytes();
  return sha256.convert(bytes).toString();
}

