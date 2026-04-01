import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/models/product.dart';
import '../../core/utils/qr_hmac.dart';
import '../../data/repository_providers.dart';
import '../auth/auth_provider.dart';
import 'anti_fraud_sheet.dart';
import 'cart_provider.dart';

class PosScanScreen extends ConsumerStatefulWidget {
  const PosScanScreen({super.key});

  @override
  ConsumerState<PosScanScreen> createState() => _PosScanScreenState();
}

class _PosScanScreenState extends ConsumerState<PosScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ensureCamera() async {
    final s = await Permission.camera.request();
    if (!s.isGranted && mounted) {
      setState(() => _error = 'Caméra refusée. Activez-la dans les paramètres.');
    }
  }

  @override
  void initState() {
    super.initState();
    _ensureCamera();
  }

  Future<void> _onBarcode(BarcodeCapture capture) async {
    if (_busy) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final raw = barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final auth = ref.read(authProvider);
    if (auth == null) {
      setState(() {
        _busy = false;
        _error = 'Non connecté';
      });
      return;
    }

    final payload = decodeQrJson(raw);
    if (payload == null) {
      setState(() {
        _busy = false;
        _error = 'QR invalide';
      });
      return;
    }

    if (payload.companyId != auth.companyId) {
      setState(() {
        _busy = false;
        _error = 'QR d’une autre entreprise (companyId différent)';
      });
      return;
    }

    if (!verifyQrPayload(payload, auth.secretKey)) {
      setState(() {
        _busy = false;
        _error = 'Signature HMAC invalide';
      });
      return;
    }

    final repo = ref.read(productsRepositoryProvider);
    final product = await repo.getById(auth.companyId, payload.productId);
    if (product == null) {
      setState(() {
        _busy = false;
        _error = 'Produit introuvable';
      });
      return;
    }

    if (product.stock < 1) {
      setState(() {
        _busy = false;
        _error = 'Stock insuffisant';
      });
      return;
    }

    if (!mounted) return;

    await _controller.stop();

    Product? toAdd = product;
    if ((product.referenceImagePath ?? '').isNotEmpty) {
      final ok = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => AntiFraudSheet(product: product),
      );
      if (ok != true) {
        if (mounted) {
          await _controller.start();
          setState(() => _busy = false);
        }
        return;
      }
    }

    ref.read(cartProvider.notifier).addProduct(toAdd);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${toAdd.name} ajouté au panier')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner QR'),
        actions: [
          IconButton(
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flash_on),
          ),
        ],
      ),
      body: Column(
        children: [
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
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null)
            Material(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
              ),
            ),
          if (_busy)
            const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Le QR doit contenir le JSON signé (HMAC) généré depuis l’écran produit.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
