import 'dart:io';

import 'package:flutter/material.dart';

import '../config/erp_config.dart';
import '../models/product.dart';

String? resolveProductImageUrl(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
  if (raw.startsWith('/')) return '$kErpBaseUrl$raw';
  return '$kErpBaseUrl/$raw';
}

Widget buildProductImage({
  required Product product,
  required BoxFit fit,
  Widget? fallback,
}) {
  final localPath = product.referenceImagePath;
  if (localPath != null && localPath.isNotEmpty && File(localPath).existsSync()) {
    return Image.file(File(localPath), fit: fit);
  }

  final remoteUrl = resolveProductImageUrl(product.referenceImageUrl);
  if (remoteUrl != null) {
    return Image.network(
      remoteUrl,
      fit: fit,
      errorBuilder: (_, __, ___) => fallback ?? const SizedBox.shrink(),
    );
  }

  return fallback ?? const SizedBox.shrink();
}
