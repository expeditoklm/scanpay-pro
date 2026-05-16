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
      showDragHandle: true,
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
    if (_busy) return;
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
          await _controller.stop();
          final created = await _showCreateProductSheet(raw, auth.companyId);
          await _controller.start();
          if (created == null) {
            _setMessage(
              'Code detecte: $raw. Produit non enregistre.',
              isError: true,
            );
            continue;
          }
          await _addProduct(created);
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
      await _controller.stop();
      if (!mounted) return;
      final ok = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => AntiFraudSheet(product: product),
      );
      await _controller.start();
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

  Future<Product?> _showCreateProductSheet(
      String code, String companyId) async {
    return showModalBottomSheet<Product?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _CreateScannedProductSheet(
        code: code,
        companyId: companyId,
      ),
    );
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

    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan continu',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      Text(
                        '$count article(s) - ${formatPriceEuro(total)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Configuration device',
                  onPressed: _openDeviceSettings,
                  icon: const Icon(Icons.settings_input_component_rounded),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Tirer le recu',
                  onPressed:
                      count == 0 || _printingReceipt ? null : _drawReceipt,
                  icon: _printingReceipt
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.receipt_long_rounded),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Panier',
                  onPressed: _openCart,
                  icon: Badge.count(
                    count: count,
                    isLabelVisible: count > 0,
                    child: const Icon(Icons.shopping_cart_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              MobileScanner(
                controller: _controller,
                onDetect: _onBarcode,
              ),
              Center(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2.5),
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: _ScanStatusPill(
                  busy: _busy,
                  message: _message ??
                      'Scannez QR produits, QR simples ou codes-barres.',
                  isError: _messageIsError,
                ),
              ),
            ],
          ),
        ),
      ],
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

class _CreateScannedProductSheet extends ConsumerStatefulWidget {
  const _CreateScannedProductSheet({
    required this.code,
    required this.companyId,
  });

  final String code;
  final String companyId;

  @override
  ConsumerState<_CreateScannedProductSheet> createState() =>
      _CreateScannedProductSheetState();
}

class _CreateScannedProductSheetState
    extends ConsumerState<_CreateScannedProductSheet> {
  final _name = TextEditingController();
  final _price = TextEditingController(text: '0');
  final _stock = TextEditingController(text: '1');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _stock.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final price = double.tryParse(_price.text.replaceAll(',', '.')) ?? -1;
    final stock = int.tryParse(_stock.text) ?? -1;
    if (name.isEmpty || price < 0 || stock < 0) {
      setState(() => _error = 'Nom, prix et stock requis.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final product = await ref.read(productsRepositoryProvider).upsert(
            Product(
              id: '',
              companyId: widget.companyId,
              name: name,
              price: price,
              stock: stock,
              sku: widget.code,
              consumerCode: widget.code,
              description: 'Cree depuis le scan du code ${widget.code}',
            ),
          );
      ref.invalidate(productsListProvider);
      if (!mounted) return;
      Navigator.of(context).pop(product);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Produit introuvable',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Code detecte: ${widget.code}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nom du produit'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _price,
            decoration: const InputDecoration(labelText: 'Prix'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _stock,
            decoration: const InputDecoration(labelText: 'Stock initial'),
            keyboardType: TextInputType.number,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_box_rounded),
            label: const Text('Enregistrer et ajouter au panier'),
          ),
        ],
      ),
    );
  }
}
