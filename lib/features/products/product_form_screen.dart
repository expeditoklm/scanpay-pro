import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/models/product.dart';
import '../../core/utils/plan_quota.dart';
import '../../core/widgets/gradient_button.dart';
import '../../data/offline_storage.dart';
import '../../data/product_extras_repository.dart';
import '../../data/repository_providers.dart';
import '../auth/auth_provider.dart';
import 'import_products_screen.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '0');
  final _picker = ImagePicker();

  String? _imagePath;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
    );
    if (picked == null) return;
    setState(() => _imagePath = picked.path);
  }

  Future<void> _takePhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
    );
    if (picked == null) return;
    setState(() => _imagePath = picked.path);
  }

  Future<void> _scanProductCode() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera refusee. Activez-la dans les parametres.',
              textAlign: TextAlign.center),
        ),
      );
      return;
    }

    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _ProductCodeScannerScreen()),
    );
    if (code == null || code.trim().isEmpty || !mounted) return;
    final normalizedCode = code.trim();
    final auth = ref.read(authProvider);
    if (auth == null) return;

    if (await _barcodeExists(auth.companyId, normalizedCode)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ce code-barres existe deja: $normalizedCode',
              textAlign: TextAlign.center),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _codeCtrl.text = normalizedCode);
  }

  Future<bool> _barcodeExists(String companyId, String code) async {
    List existing;
    try {
      existing = await ref.read(productsRepositoryProvider).listProducts(companyId);
    } catch (_) {
      existing = await OfflineStorage().loadProducts(companyId);
    }
    return existing.any((product) {
      return (product.sku ?? '').trim() == code ||
          (product.consumerCode ?? '').trim() == code;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = ref.read(authProvider);
    if (auth == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      List existing;
      try {
        existing = await ref
            .read(productsRepositoryProvider)
            .listProducts(auth.companyId);
      } catch (_) {
        existing = await OfflineStorage().loadProducts(auth.companyId);
      }

      final normalizedName = _nameCtrl.text.trim().toLowerCase();
      final duplicate = existing.any(
        (product) => product.name.trim().toLowerCase() == normalizedName,
      );
      if (duplicate) {
        throw Exception(
          'Un produit avec le libelle "${_nameCtrl.text.trim()}" existe deja.',
        );
      }

      final productCode = _codeCtrl.text.trim();
      if (productCode.isNotEmpty) {
        final duplicateCode = existing.any((product) {
          return (product.sku ?? '').trim() == productCode ||
              (product.consumerCode ?? '').trim() == productCode;
        });
        if (duplicateCode) {
          throw Exception(
            'Ce code-barres est deja associe a un autre produit.',
          );
        }
      }

      final plan = auth.plan.isEmpty ? 'free' : auth.plan;
      final quotaCheck = checkProductQuota(
        plan: plan,
        existingCount: existing.length,
      );
      if (!quotaCheck.allowed) {
        throw Exception(quotaCheck.errorMessage);
      }

      final price = double.parse(_priceCtrl.text.replaceAll(',', '.'));
      final stock = int.parse(_stockCtrl.text.trim());
      final repo = ref.read(productsRepositoryProvider);
      final erpRepo = ref.read(erpProductsRepositoryProvider);
      final extrasRepo = ref.read(productExtrasRepositoryProvider);
      final imgService = ref.read(productImageServiceProvider);

      final product = Product(
        id: '',
        companyId: auth.companyId,
        name: _nameCtrl.text.trim(),
        price: price,
        stock: stock,
        sku: productCode.isEmpty ? null : productCode,
        consumerCode: productCode.isEmpty ? null : productCode,
      );

      final saved = await repo.upsert(product);
      var syncedRemotely = true;

      if (_imagePath != null && _imagePath!.isNotEmpty) {
        final persisted = await imgService.persistReferenceImage(
          companyId: auth.companyId,
          productId: saved.id,
          sourcePath: _imagePath!,
        );
        await extrasRepo.set(
          companyId: auth.companyId,
          productId: saved.id,
          extras: ProductExtras(
            referenceImagePath: persisted.path,
            referenceImageHash: persisted.sha256,
            pendingUpload: true,
          ),
        );
        await repo.upsert(
          saved.copyWith(
            referenceImagePath: persisted.path,
            referenceImageHash: persisted.sha256,
          ),
        );
        try {
          await erpRepo.uploadProductImage(
            companyId: auth.companyId,
            productId: saved.id,
            sourcePath: persisted.path,
            referenceImageHash: persisted.sha256,
          );
          await extrasRepo.markUploadSynced(
            companyId: auth.companyId,
            productId: saved.id,
          );
        } catch (_) {
          syncedRemotely = false;
        }
      }

      if (!mounted) return;
      if (_imagePath != null && _imagePath!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              syncedRemotely
                  ? 'Produit et image sauvegardes'
                  : 'Produit sauvegarde. Image en attente de synchronisation.',
              textAlign: TextAlign.center,),
          ),
        );
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      final msg = error.toString();
      final isNetwork = msg.contains('SocketException') ||
          msg.contains('ClientException') ||
          msg.contains('Connection') ||
          msg.contains('Network is unreachable');
      if (isNetwork) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Produit enregistre hors connexion. Synchronisation automatique plus tard.',
              textAlign: TextAlign.center,),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _error = msg
              .replaceAll('Exception: ', '')
              .replaceAll('Exception(', '')
              .replaceFirst(RegExp(r'\)$'), '');
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FA),
      body: SafeArea(
        child: Column(
          children: [
            // ── Hero header ──────────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1565D8), Color(0xFF22C1C3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.add_box_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nouveau produit',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Remplissez les infos ci-dessous',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── Bouton Importer CSV ──────────────────────────────
                  GestureDetector(
                    onTap: () async {
                      await Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => const ImportProductsScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.30),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.upload_file_rounded,
                              color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Importer',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Form body ────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Section infos ──────────────────────────────────
                      _sectionLabel('Informations produit', Icons.inventory_2_rounded),
                      const SizedBox(height: 12),
                      _field(
                        controller: _nameCtrl,
                        label: 'Nom du produit',
                        hint: 'Ex : Savon premium',
                        icon: Icons.label_rounded,
                        action: TextInputAction.next,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Requis' : null,
                      ),
                      const SizedBox(height: 12),
                      // Code-barres + scan button
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _field(
                              controller: _codeCtrl,
                              label: 'Code-barres',
                              hint: 'Scannez ou saisissez',
                              icon: Icons.qr_code_rounded,
                              action: TextInputAction.next,
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: _scanProductCode,
                            child: Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF1565D8), Color(0xFF22C1C3)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x441565D8),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.document_scanner_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              controller: _priceCtrl,
                              label: 'Prix (FCFA)',
                              hint: 'Ex : 2500',
                              icon: Icons.payments_rounded,
                              action: TextInputAction.next,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Requis';
                                final p = double.tryParse(v.replaceAll(',', '.'));
                                if (p == null || p < 0) return 'Invalide';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _field(
                              controller: _stockCtrl,
                              label: 'Stock initial',
                              hint: 'Ex : 10',
                              icon: Icons.warehouse_rounded,
                              action: TextInputAction.done,
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Requis';
                                final s = int.tryParse(v.trim());
                                if (s == null || s < 0) return 'Invalide';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // ── Section image ──────────────────────────────────
                      _sectionLabel('Image de référence', Icons.image_rounded),
                      const SizedBox(height: 4),
                      const Text(
                        'Optionnel — aide la vérification anti-fraude au scan.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 12),
                      if (_imagePath != null)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: AspectRatio(
                                aspectRatio: 4 / 3,
                                child: Image.file(
                                  File(_imagePath!),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Row(
                                children: [
                                  _imageOverlayBtn(
                                    Icons.photo_library_rounded,
                                    _pickImage,
                                  ),
                                  const SizedBox(width: 8),
                                  _imageOverlayBtn(
                                    Icons.camera_alt_rounded,
                                    _takePhoto,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: _imagePickerTile(
                                icon: Icons.photo_library_rounded,
                                label: 'Galerie',
                                color: const Color(0xFF1565D8),
                                onTap: _pickImage,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _imagePickerTile(
                                icon: Icons.camera_alt_rounded,
                                label: 'Appareil photo',
                                color: const Color(0xFF22C1C3),
                                onTap: _takePhoto,
                              ),
                            ),
                          ],
                        ),
                      // ── Error ──────────────────────────────────────────
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            border: Border.all(color: const Color(0xFFFDA4AF)),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: Color(0xFFE11D48),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Color(0xFFBE123C),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      GradientButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Enregistrer le produit',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 17, color: const Color(0xFF1565D8)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required TextInputAction action,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      textInputAction: action,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD7E2F2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF1565D8), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE11D48)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.5),
        ),
      ),
    );
  }

  Widget _imagePickerTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD7E2F2)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0F172A),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageOverlayBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 17),
      ),
    );
  }
}

class _ProductCodeScannerScreen extends StatefulWidget {
  const _ProductCodeScannerScreen();

  @override
  State<_ProductCodeScannerScreen> createState() =>
      _ProductCodeScannerScreenState();
}

class _ProductCodeScannerScreenState extends State<_ProductCodeScannerScreen> {
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
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    String? code;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw != null && raw.isNotEmpty) {
        code = raw;
        break;
      }
    }
    if (code == null) return;
    _handled = true;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner code-barres')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 260,
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2.5),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.68),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Text(
                  'Scannez le code-barres du produit a enregistrer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
