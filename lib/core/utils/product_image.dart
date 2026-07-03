import 'dart:io';

import 'package:flutter/material.dart';

import '../config/erp_config.dart';
import '../models/product.dart';
import '../widgets/shimmer_box.dart';

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
  // ── Image locale (cache disque) ──────────────────────────────────────────
  final localPath = product.referenceImagePath;
  if (localPath != null && localPath.isNotEmpty && File(localPath).existsSync()) {
    return Image.file(File(localPath), fit: fit);
  }

  // ── Image distante avec shimmer + fondu entrant ──────────────────────────
  final remoteUrl = resolveProductImageUrl(product.referenceImageUrl);
  if (remoteUrl != null) {
    return Image.network(
      remoteUrl,
      fit: fit,
      // Shimmer tant que les octets n'ont pas fini de charger
      loadingBuilder: (_, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const ShimmerBox();
      },
      // Fondu doux (300 ms) quand l'image est prête
      frameBuilder: (_, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (_, __, ___) => fallback ?? const SizedBox.shrink(),
    );
  }

  return fallback ?? const SizedBox.shrink();
}
