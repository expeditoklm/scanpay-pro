import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/product.dart';
import '../../core/services/image_label_match.dart';
import '../../core/utils/product_image.dart';
import '../../data/repository_providers.dart';

const _kBlue1 = Color(0xFF1565D8);
const _kBlue2 = Color(0xFF0D47A1);
const _kTeal  = Color(0xFF22C1C3);
const _kBg    = Color(0xFFF0F4FA);

class AntiFraudSheet extends ConsumerStatefulWidget {
  const AntiFraudSheet({super.key, required this.product});
  final Product product;

  @override
  ConsumerState<AntiFraudSheet> createState() => _AntiFraudSheetState();
}

class _AntiFraudSheetState extends ConsumerState<AntiFraudSheet> {
  final _picker = ImagePicker();
  String? _livePath;
  bool   _loading = false;
  double? _score;
  String? _error;
  String? _refPath;

  Future<void> _capture() async {
    final picked = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1600);
    if (picked == null || !mounted) return;
    setState(() { _livePath = picked.path; _score = null; _error = null; });
  }

  Future<void> _runCompare() async {
    if (_livePath == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final svc = ref.read(productImageServiceProvider);
      final saved = await svc.ensureLocalReferenceImage(
        companyId: widget.product.companyId,
        productId: widget.product.id,
        localPath: widget.product.referenceImagePath,
        remoteUrl: widget.product.referenceImageUrl,
      );
      if (saved == null) {
        if (mounted) setState(() => _error = 'Aucune image de reference.');
        return;
      }
      final score = await ImageLabelMatch.similarityScore(saved.path, _livePath!);
      if (!mounted) return;
      setState(() { _refPath = saved.path; _score = score; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasRef = (widget.product.referenceImagePath ?? '').isNotEmpty ||
        (widget.product.referenceImageUrl ?? '').isNotEmpty;
    final canValidate = !hasRef || (_livePath != null && (_score ?? 0) >= 0.25);
    final scoreOk     = (_score ?? 0) >= 0.25;

    // ── root: fixed-width via MediaQuery ──
    final screenW = MediaQuery.of(context).size.width;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return SizedBox(
      width: screenW,
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── Header ─────────────────────────────────────────────────
            Container(
              width: screenW,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_kBlue2, _kBlue1, _kTeal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 38, height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.verified_user_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Verification Anti-fraude',
                            style: TextStyle(color: Colors.white,
                                fontSize: 16, fontWeight: FontWeight.w800)),
                        Text(widget.product.name,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.80),
                                fontSize: 12.5),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    )),
                  ]),
                ],
              ),
            ),

            // ── Body ───────────────────────────────────────────────────
            Container(
              width: screenW,
              color: _kBg,
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPad),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  // Images
                  if (hasRef)
                    SizedBox(
                      height: (screenW - 44) / 2, // square slots
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _Slot(
                            label: 'Reference',
                            icon: Icons.inventory_2_rounded,
                            active: true,
                            child: _refPath != null
                                ? Image.file(File(_refPath!), fit: BoxFit.cover)
                                : buildProductImage(product: widget.product,
                                    fit: BoxFit.cover,
                                    fallback: _emptySlot(Icons.image_not_supported_outlined)),
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: _Slot(
                            label: 'Scanne',
                            icon: Icons.camera_alt_rounded,
                            active: _livePath != null,
                            child: _livePath != null
                                ? Image.file(File(_livePath!), fit: BoxFit.cover)
                                : _emptySlot(Icons.photo_camera_outlined, hint: 'Photo'),
                          )),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFFE082))),
                      child: const Row(children: [
                        Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
                        SizedBox(width: 10),
                        Expanded(child: Text('Aucune image de reference.',
                            style: TextStyle(fontSize: 13))),
                      ]),
                    ),

                  const SizedBox(height: 12),

                  // Bouton photo
                  _FlatBtn(
                    icon: Icons.camera_alt_rounded,
                    label: 'Prendre une photo',
                    enabled: !_loading,
                    onTap: _capture,
                  ),

                  // Bouton comparer
                  if (hasRef && _livePath != null) ...[
                    const SizedBox(height: 8),
                    _FlatBtn(
                      icon: Icons.compare_rounded,
                      label: 'Lancer la comparaison',
                      enabled: !_loading,
                      onTap: _runCompare,
                      outlined: true,
                      loading: _loading,
                    ),
                  ],

                  // Score
                  if (_score != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: scoreOk ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: scoreOk
                            ? const Color(0xFF6EE7B7) : const Color(0xFFFDA4AF)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: scoreOk
                                ? const Color(0xFF059669) : const Color(0xFFE11D48),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                              scoreOk ? Icons.check_rounded : Icons.close_rounded,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${(_score! * 100).toStringAsFixed(0)}% de similarite',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14,
                                    color: scoreOk
                                        ? const Color(0xFF065F46) : const Color(0xFF9F1239))),
                            Text(scoreOk ? 'Correspondance ok' : 'Ecart important',
                                style: TextStyle(fontSize: 12,
                                    color: scoreOk
                                        ? const Color(0xFF059669) : const Color(0xFFE11D48))),
                          ],
                        )),
                      ]),
                    ),
                  ],

                  // Erreur
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDA4AF))),
                      child: Text(_error!,
                          style: const TextStyle(
                              color: Color(0xFFBE123C), fontSize: 12.5)),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Actions — 3 boutons avec widths explicites
                  Row(children: [
                    // Annuler
                    Expanded(child: _FlatBtn(
                      label: 'Annuler',
                      enabled: true,
                      outlined: true,
                      onTap: () => Navigator.of(context).pop(false),
                    )),
                    const SizedBox(width: 8),
                    // Passer — largeur fixe pour éviter les contraintes infinies
                    SizedBox(
                      width: 90,
                      child: _FlatBtn(
                        label: 'Passer',
                        enabled: true,
                        outlined: true,
                        blue: true,
                        onTap: () => Navigator.of(context).pop(true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Valider
                    Expanded(child: _FlatBtn(
                      label: 'Valider',
                      enabled: canValidate,
                      gradient: canValidate,
                      onTap: canValidate
                          ? () => Navigator.of(context).pop(true) : null,
                    )),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptySlot(IconData icon, {String? hint}) => Container(
    color: const Color(0xFFF1F5F9),
    alignment: Alignment.center,
    child: Column(mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 32, color: const Color(0xFFCBD5E1)),
      if (hint != null) ...[
        const SizedBox(height: 4),
        Text(hint, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
      ],
    ]),
  );
}

// ── Slot image ────────────────────────────────────────────────────────────────
class _Slot extends StatelessWidget {
  const _Slot({required this.label, required this.icon,
      required this.active, required this.child});
  final String label; final IconData icon;
  final bool active; final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13,
            color: active ? _kBlue1 : const Color(0xFF94A3B8)),
        const SizedBox(width: 5),
        Flexible(child: Text(label, style: TextStyle(fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: active ? _kBlue1 : const Color(0xFF94A3B8)))),
      ]),
      const SizedBox(height: 5),
      Expanded(child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: child,
      )),
    ],
  );
}

// ── Bouton plat — AUCUN widget Material/Button pour éviter les crashes de layout
class _FlatBtn extends StatelessWidget {
  const _FlatBtn({
    this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.outlined = false,
    this.blue = false,
    this.gradient = false,
    this.loading = false,
  });
  final IconData? icon;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;
  final bool outlined;
  final bool blue;
  final bool gradient;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          gradient: gradient && enabled
              ? const LinearGradient(
                  colors: [_kBlue2, _kBlue1, Color(0xFF64B5F6)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight)
              : null,
          color: gradient && enabled
              ? null
              : outlined
                  ? Colors.white
                  : enabled
                      ? _kBlue1
                      : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(14),
          border: outlined
              ? Border.all(
                  color: blue
                      ? _kBlue1.withOpacity(0.5)
                      : const Color(0xFFCBD5E1),
                  width: 1.5)
              : null,
          boxShadow: gradient && enabled
              ? [BoxShadow(
                  color: _kBlue1.withOpacity(0.25),
                  blurRadius: 8, offset: const Offset(0, 3))]
              : null,
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: _kBlue1))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon!,
                        size: 17,
                        color: _textColor(enabled, outlined, gradient, blue)),
                    const SizedBox(width: 7),
                  ],
                  Text(label, style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13.5,
                      color: _textColor(enabled, outlined, gradient, blue))),
                ],
              ),
      ),
    );
  }

  Color _textColor(bool enabled, bool outlined, bool gradient, bool blue) {
    if (!enabled) return const Color(0xFF94A3B8);
    if (outlined) return blue ? _kBlue1 : const Color(0xFF64748B);
    return Colors.white;
  }
}
