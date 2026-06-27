import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/product.dart';
import '../../core/services/device_feedback_service.dart';
import '../../core/services/xprinter_service.dart';
import '../../core/utils/price_formatter.dart';
import '../../core/utils/qr_hmac.dart';
import '../../data/repository_providers.dart';
import '../auth/auth_provider.dart';
import '../billing/billing_providers.dart';
import '../products/products_providers.dart';
import 'anti_fraud_sheet.dart';
import 'cart_provider.dart';
import 'pos_cart_screen.dart';
import 'xprinter_config_sheet.dart';

class PosScanScreen extends ConsumerStatefulWidget {
  const PosScanScreen({
    super.key,
    this.embedded = false,
    this.active = true,
  });

  final bool embedded;
  final bool active;

  @override
  ConsumerState<PosScanScreen> createState() => _PosScanScreenState();
}

class _PosScanScreenState extends ConsumerState<PosScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.qrCode,
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.itf,
    ],
  );
  final DeviceFeedbackService _feedback = const DeviceFeedbackService();
  final XPrinterService _xprinter = const XPrinterService();
  final Map<String, DateTime> _recentScans = {};

  bool _busy = false;
  bool _inModal = false;   // bloque les scans pendant un bottom sheet
  bool _printingReceipt = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _ensureCamera();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PosScanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active) return;
    if (widget.active) {
      _controller.start();
    } else {
      _controller.stop();
    }
  }

  Future<void> _ensureCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted && mounted) {
      setState(() {
        _message = 'Camera refusee. Activez-la dans les parametres.';
        _messageIsError = true;
      });
    }
  }

  Future<void> _openDeviceSettings() async {
    await _feedback.actionSuccess();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const XPrinterConfigSheet(),
    );
  }

  bool _isCoolingDown(String code) {
    final now = DateTime.now();
    _recentScans.removeWhere(
      (_, time) => now.difference(time) > const Duration(seconds: 3),
    );
    final last = _recentScans[code];
    if (last != null && now.difference(last) < const Duration(seconds: 2)) {
      return true;
    }
    _recentScans[code] = now;
    return false;
  }

  Future<void> _onBarcode(BarcodeCapture capture) async {
    if (_busy || _inModal) return;
    final codes = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .where((value) => !_isCoolingDown(value))
        .toSet()
        .toList();
    if (codes.isEmpty) return;

    setState(() {
      _busy = true;
      _message = null;
      _messageIsError = false;
    });

    try {
      final auth = ref.read(authProvider);
      if (auth == null) {
        await _feedback.scanWarning();
        _setMessage('Non connecte', isError: true);
        return;
      }

      for (final raw in codes) {
        final product =
            await _resolveProduct(raw, auth.companyId, auth.secretKey);
        if (product == null) {
          await _feedback.scanWarning();
          _setMessage(
            'Produit introuvable pour ce code. Enregistrez-le d abord depuis Produits > Nouveau produit.',
            isError: true,
          );
          continue;
        }

        await _addProduct(product);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Product?> _resolveProduct(
    String raw,
    String companyId,
    String secretKey,
  ) async {
    final repo = ref.read(productsRepositoryProvider);
    final payload = decodeQrJson(raw);
    if (payload != null) {
      if (payload.companyId != companyId ||
          !verifyQrPayload(payload, secretKey)) {
        return null;
      }
      Product? product = await repo.getById(companyId, payload.productId);
      if (product == null && (payload.authCode?.isNotEmpty ?? false)) {
        product = await repo.getByConsumerCode(companyId, payload.authCode!);
      }
      return product;
    }

    return await repo.getByConsumerCode(companyId, raw) ??
        await repo.getBySku(companyId, raw);
  }

  Future<void> _addProduct(Product product) async {
    if (product.stock < 1) {
      await _feedback.scanWarning();
      _setMessage('Stock insuffisant pour ${product.name}', isError: true);
      return;
    }

    final hasReferenceImage = (product.referenceImagePath ?? '').isNotEmpty ||
        (product.referenceImageUrl ?? '').isNotEmpty;
    if (hasReferenceImage) {
      // On ne stoppe PAS la caméra : stop()/start() déclenche
      // onCameraAccessPrioritiesChanged qui cause un RenderBox layout crash
      // dans MobileScanner. On bloque juste le traitement des scans.
      if (mounted) setState(() => _inModal = true);
      bool? ok;
      try {
        if (!mounted) return;
        ok = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => AntiFraudSheet(product: product),
        ).timeout(
          const Duration(seconds: 60),
          onTimeout: () => null, // libère _busy si le sheet reste bloqué
        );
      } catch (_) {
        ok = null;
      } finally {
        if (mounted) setState(() => _inModal = false);
      }
      if (ok != true) {
        await _feedback.scanWarning();
        _setMessage('Ajout annule pour ${product.name}', isError: true);
        return;
      }
    }

    ref.read(cartProvider.notifier).addProduct(product);
    await _feedback.scanSuccess();
    _setMessage('${product.name} ajoute au panier');
  }

  void _setMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _messageIsError = isError;
    });
  }

  void _openCart() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const PosCartScreen()),
    );
  }

  Future<void> _drawReceipt() async {
    final auth = ref.read(authProvider);
    final lines = ref.read(cartProvider);
    if (auth == null || lines.isEmpty || _printingReceipt) return;

    setState(() {
      _printingReceipt = true;
      _message = 'Preparation du recu...';
      _messageIsError = false;
    });

    try {
      await _feedback.actionSuccess();
      final invoice = await ref.read(invoicesRepositoryProvider).recordSale(
        companyId: auth.companyId,
        invoiceId: const Uuid().v4(),
        lines: [
          for (final line in lines)
            (product: line.product, qty: line.quantity),
        ],
      );
      if (invoice == null) {
        await _feedback.scanWarning();
        _setMessage('Stock insuffisant pour tirer le recu.', isError: true);
        return;
      }
      ref.read(cartProvider.notifier).clear();
      ref.invalidate(productsListProvider);
      ref.read(salesRefreshProvider.notifier).state++;
      final printResult = await _xprinter.printSavedInvoice(invoice);
      if (printResult.success) {
        await _feedback.actionSuccess();
      } else {
        await _feedback.scanWarning();
      }
      _setMessage(printResult.message, isError: !printResult.success);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => InvoicePreviewScreen(invoice: invoice)),
      );
    } catch (error) {
      await _feedback.scanWarning();
      _setMessage(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _printingReceipt = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) return _buildScannerContent(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Scan caisse')),
      body: _buildScannerContent(context),
    );
  }

  Widget _buildScannerContent(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final count = cart.fold<int>(0, (sum, line) => sum + line.quantity);
    final total = cart.fold<double>(0, (sum, line) => sum + line.lineTotal);

    const scanSize = 260.0;
    const cornerLen = 28.0;
    const cornerWidth = 4.0;
    const cornerRadius = 6.0;
    const cornerColor = Color(0xFF22C1C3);

    return Stack(
      children: [
        // ── Caméra plein écran ──────────────────────────────────────────
        Positioned.fill(
          child: MobileScanner(
            controller: _controller,
            onDetect: _onBarcode,
          ),
        ),

        // ── Overlay sombre (4 zones autour du cadre) ────────────────────
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalH = constraints.maxHeight;
              final totalW = constraints.maxWidth;
              final top = (totalH - scanSize) / 2;
              final left = (totalW - scanSize) / 2;

              return Stack(
                children: [
                  // Haut
                  Positioned(
                    top: 0, left: 0, right: 0,
                    height: top,
                    child: _overlay(),
                  ),
                  // Bas
                  Positioned(
                    top: top + scanSize, left: 0, right: 0, bottom: 0,
                    child: _overlay(),
                  ),
                  // Gauche
                  Positioned(
                    top: top, left: 0,
                    width: left,
                    height: scanSize,
                    child: _overlay(),
                  ),
                  // Droite
                  Positioned(
                    top: top,
                    left: left + scanSize,
                    right: 0,
                    height: scanSize,
                    child: _overlay(),
                  ),
                ],
              );
            },
          ),
        ),

        // ── Coins du cadre de scan (centrés) ────────────────────────────
        Center(
          child: SizedBox(
            width: scanSize,
            height: scanSize,
            child: Stack(
              children: [
                // Coin haut-gauche
                Positioned(
                  top: 0, left: 0,
                  child: _Corner(
                    topLeft: true,
                    len: cornerLen, width: cornerWidth,
                    radius: cornerRadius, color: cornerColor,
                  ),
                ),
                // Coin haut-droit
                Positioned(
                  top: 0, right: 0,
                  child: _Corner(
                    topRight: true,
                    len: cornerLen, width: cornerWidth,
                    radius: cornerRadius, color: cornerColor,
                  ),
                ),
                // Coin bas-gauche
                Positioned(
                  bottom: 0, left: 0,
                  child: _Corner(
                    bottomLeft: true,
                    len: cornerLen, width: cornerWidth,
                    radius: cornerRadius, color: cornerColor,
                  ),
                ),
                // Coin bas-droit
                Positioned(
                  bottom: 0, right: 0,
                  child: _Corner(
                    bottomRight: true,
                    len: cornerLen, width: cornerWidth,
                    radius: cornerRadius, color: cornerColor,
                  ),
                ),
                // Label central
                const Center(
                  child: Text(
                    'Pointez sur le QR code\nou le code-barres',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Header flottant ─────────────────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(
                children: [
                  // Info panier
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.qr_code_scanner_rounded,
                            color: Color(0xFF22C1C3),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Caisse — Scan continu',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                count == 0
                                    ? 'Panier vide'
                                    : '$count article${count > 1 ? 's' : ''} · ${formatPriceEuro(total)}',
                                style: TextStyle(
                                  color: count > 0
                                      ? const Color(0xFF22C1C3)
                                      : Colors.white60,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Bouton device
                  _ActionBtn(
                    icon: Icons.settings_input_component_rounded,
                    onTap: _openDeviceSettings,
                  ),
                  const SizedBox(width: 8),
                  // Bouton reçu
                  _ActionBtn(
                    icon: _printingReceipt
                        ? Icons.hourglass_top_rounded
                        : Icons.receipt_long_rounded,
                    onTap: count == 0 || _printingReceipt ? null : _drawReceipt,
                    enabled: count > 0 && !_printingReceipt,
                  ),
                  const SizedBox(width: 8),
                  // Bouton panier
                  _ActionBtn(
                    icon: Icons.shopping_cart_rounded,
                    onTap: _openCart,
                    badge: count > 0 ? '$count' : null,
                    accent: true,
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Status pill (bas) ───────────────────────────────────────────
        Positioned(
          left: 20,
          right: 20,
          bottom: 28,
          child: _ScanStatusPill(
            busy: _busy,
            message: _message ?? 'Pointez sur un QR code ou code-barres.',
            isError: _messageIsError,
          ),
        ),
      ],
    );
  }

  Widget _overlay() => ColoredBox(
        color: Colors.black.withValues(alpha: 0.52),
      );
}

// ── Corner marker ─────────────────────────────────────────────────────────────
class _Corner extends StatelessWidget {
  const _Corner({
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
    required this.len,
    required this.width,
    required this.radius,
    required this.color,
  });

  final bool topLeft, topRight, bottomLeft, bottomRight;
  final double len, width, radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    BorderRadius br;
    if (topLeft) {
      br = BorderRadius.only(topLeft: Radius.circular(radius));
    } else if (topRight) {
      br = BorderRadius.only(topRight: Radius.circular(radius));
    } else if (bottomLeft) {
      br = BorderRadius.only(bottomLeft: Radius.circular(radius));
    } else {
      br = BorderRadius.only(bottomRight: Radius.circular(radius));
    }

    final borderTop = topLeft || topRight;
    final borderBottom = bottomLeft || bottomRight;
    final borderLeft = topLeft || bottomLeft;
    final borderRight = topRight || bottomRight;

    return SizedBox(
      width: len,
      height: len,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: br,
          border: Border(
            top: borderTop
                ? BorderSide(color: color, width: width)
                : BorderSide.none,
            bottom: borderBottom
                ? BorderSide(color: color, width: width)
                : BorderSide.none,
            left: borderLeft
                ? BorderSide(color: color, width: width)
                : BorderSide.none,
            right: borderRight
                ? BorderSide(color: color, width: width)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// ── Bouton action header ───────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.onTap,
    this.badge,
    this.accent = false,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? badge;
  final bool accent;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bg = accent
        ? const Color(0xFF1565D8)
        : Colors.black.withValues(alpha: 0.55);
    final fg = enabled ? Colors.white : Colors.white38;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: accent ? 0 : 0.12),
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(child: Icon(icon, color: fg, size: 20)),
            if (badge != null)
              Positioned(
                top: -5,
                right: -5,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScanStatusPill extends StatelessWidget {
  const _ScanStatusPill({
    required this.busy,
    required this.message,
    required this.isError,
  });

  final bool busy;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final bg = isError
        ? Theme.of(context).colorScheme.errorContainer
        : Colors.black.withValues(alpha: 0.68);
    final fg =
        isError ? Theme.of(context).colorScheme.onErrorContainer : Colors.white;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            if (busy) ...[
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: fg,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: fg, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
