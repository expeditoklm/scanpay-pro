import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/product.dart';
import '../utils/price_formatter.dart';
import '../utils/product_image.dart';

class ProductShareService {
  ProductShareService({http.Client? client}) : _client = client ?? http.Client();

  static const MethodChannel _channel = MethodChannel('quick_sell_pay/whatsapp_share');

  final http.Client _client;

  Future<void> shareProductsToWhatsApp(List<Product> products) async {
    if (products.isEmpty) {
      throw Exception('Aucun produit selectionne');
    }

    final imagePaths = <String>[];
    for (final product in products) {
      final productImagePaths = await _prepareShareImages(product);
      imagePaths.addAll(productImagePaths);
    }

    try {
      await _channel.invokeMethod<void>('shareProducts', {
        'imagePaths': imagePaths,
        'caption': _buildCaptionForProducts(products),
      });
    } on PlatformException catch (error) {
      final message = error.message ?? 'Partage WhatsApp impossible';
      throw Exception(message);
    }
  }

  Future<List<String>> _prepareShareImages(Product product) async {
    Uint8List? sourceBytes;
    final localPath = product.referenceImagePath;
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (await file.exists()) {
        sourceBytes = await file.readAsBytes();
      }
    }

    sourceBytes ??= await _loadRemoteImageBytes(product.referenceImageUrl);
    if (sourceBytes != null && sourceBytes.isNotEmpty) {
      final cleanImagePath = await _buildCleanShareImage(product, sourceBytes);
      final badgedImagePath = await _buildBadgedImage(product, sourceBytes);
      return [badgedImagePath, cleanImagePath];
    }

    final fallbackImagePath = await _buildFallbackImage(product);
    return [fallbackImagePath];
  }

  Future<String> _buildCleanShareImage(Product product, Uint8List sourceBytes) async {
    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/product_clean_${product.id}_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(sourceBytes, flush: true);
    return file.path;
  }

  Future<String> _buildBadgedImage(Product product, Uint8List sourceBytes) async {
    final codec = await ui.instantiateImageCodec(sourceBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final width = image.width.toDouble();
    final height = image.height.toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

    paintImage(
      canvas: canvas,
      rect: Rect.fromLTWH(0, 0, width, height),
      image: image,
      fit: BoxFit.cover,
    );

    final horizontalPadding = width * 0.045;
    final bottomPadding = height * 0.05;
    final badgeWidth = width - (horizontalPadding * 2);
    final badgeHeight = height * 0.22;
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        horizontalPadding,
        height - badgeHeight - bottomPadding,
        badgeWidth,
        badgeHeight,
      ),
      Radius.circular(width * 0.04),
    );

    canvas.drawShadow(
      Path()..addRRect(badgeRect),
      Colors.black.withValues(alpha: 0.28),
      width * 0.03,
      false,
    );

    canvas.drawRRect(
      badgeRect,
      Paint()..color = const Color(0xCC0F172A),
    );

    final top = badgeRect.outerRect.top + badgeHeight * 0.16;
    final left = badgeRect.outerRect.left + badgeWidth * 0.06;

    _paintText(
      canvas,
      text: product.name.trim().isEmpty ? 'Produit' : product.name.trim(),
      offset: Offset(left, top),
      maxWidth: badgeWidth * 0.88,
      maxLines: 2,
      style: TextStyle(
        fontSize: width * 0.055,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
    );

    _paintText(
      canvas,
      text: formatPriceEuro(product.price),
      offset: Offset(left, top + badgeHeight * 0.44),
      maxWidth: badgeWidth * 0.88,
      maxLines: 1,
      style: TextStyle(
        fontSize: width * 0.05,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF86EFAC),
      ),
    );

    final picture = recorder.endRecording();
    final resultImage = await picture.toImage(image.width, image.height);
    final bytes = await resultImage.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      throw Exception('Impossible de preparer l image du produit');
    }

    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/product_badged_${product.id}_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    return file.path;
  }

  Future<String> _buildFallbackImage(Product product) async {
    const width = 1080.0;
    const height = 1080.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

    final backgroundPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF1565D8), Color(0xFF22C1C3), Color(0xFFF8FAFC)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(const Rect.fromLTWH(0, 0, width, height));
    canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), backgroundPaint);

    final innerRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(60, 60, 960, 960),
      const Radius.circular(48),
    );
    canvas.drawRRect(
      innerRect,
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );

    _paintText(
      canvas,
      text: product.name.isEmpty ? '?' : product.name[0].toUpperCase(),
      offset: const Offset(430, 250),
      maxWidth: 220,
      style: const TextStyle(
        fontSize: 180,
        fontWeight: FontWeight.w800,
        color: Color(0xFF1565D8),
      ),
    );

    _paintText(
      canvas,
      text: product.name,
      offset: const Offset(120, 560),
      maxWidth: 840,
      maxLines: 3,
      style: const TextStyle(
        fontSize: 54,
        fontWeight: FontWeight.w700,
        color: Color(0xFF0F172A),
      ),
    );

    _paintText(
      canvas,
      text: formatPriceEuro(product.price),
      offset: const Offset(120, 780),
      maxWidth: 840,
      maxLines: 1,
      style: const TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1565D8),
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      throw Exception('Impossible de generer l image du produit');
    }

    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/product_fallback_${product.id}_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    return file.path;
  }

  Future<Uint8List?> _loadRemoteImageBytes(String? rawUrl) async {
    final resolvedUrl = resolveProductImageUrl(rawUrl);
    if (resolvedUrl == null) return null;

    try {
      final response = await _client
          .get(Uri.parse(resolvedUrl))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      return response.bodyBytes;
    } catch (_) {
      // Hors-ligne ou timeout → on utilise l'image de fallback générée localement
      return null;
    }
  }

  String _buildCaption(Product product) {
    final description = (product.description ?? '').trim();
    final firstLine = '${product.name} ${formatPriceEuro(product.price)}'.trim();
    if (description.isEmpty) {
      return firstLine;
    }
    return '$firstLine\n\n$description';
  }

  String _buildCaptionForProducts(List<Product> products) {
    return products.map(_buildCaption).join('\n\n');
  }

  void _paintText(
    Canvas canvas, {
    required String text,
    required Offset offset,
    required double maxWidth,
    required TextStyle style,
    int? maxLines,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: maxLines == null ? null : '...',
    )..layout(maxWidth: maxWidth);

    painter.paint(canvas, offset);
  }
}
