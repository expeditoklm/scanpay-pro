import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
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

  // ── Image distante avec cache disque + shimmer + fondu ──────────────────
  final remoteUrl = resolveProductImageUrl(product.referenceImageUrl);
  if (remoteUrl != null) {
    return CachedNetworkImage(
      imageUrl: remoteUrl,
      fit: fit,
      placeholder: (_, __) => const ShimmerBox(),
      errorWidget: (_, __, ___) => fallback ?? const SizedBox.shrink(),
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 100),
    );
  }

  return fallback ?? const SizedBox.shrink();
}
