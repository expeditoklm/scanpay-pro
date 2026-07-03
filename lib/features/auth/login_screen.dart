import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/widgets/exit_guard.dart';
import '../../core/widgets/gradient_button.dart';
import 'auth_provider.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kBlue1  = Color(0xFF1565D8);
const _kBlue2  = Color(0xFF0D47A1);
const _kTeal   = Color(0xFF22C1C3);
const _kBorder = Color(0xFFD7E2F2);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static final RegExp _emailPattern =
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

  final _picker = ImagePicker();

  // ── Clés formulaire ───────────────────────────────────────────────────────
  final _loginKey = GlobalKey<FormState>();
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();
  final _step4Key = GlobalKey<FormState>();

  // ── Contrôleurs ───────────────────────────────────────────────────────────
  final _companyCtrl         = TextEditingController(text: 'Boutique Demo');
  final _commercialNameCtrl  = TextEditingController(text: 'Boutique Demo');
  final _ifuCtrl             = TextEditingController();
  final _rccmCtrl            = TextEditingController();
  final _addressCtrl         = TextEditingController();
  final _phoneCtrl           = TextEditingController();
  final _mecefTokenCtrl      = TextEditingController();
  final _contactEmailCtrl    = TextEditingController();
  final _emailCtrl           = TextEditingController(text: 'admin@demo.tpe-qr.com');
  final _passwordCtrl        = TextEditingController(text: 'AdminDemo123!');
  final _confirmPasswordCtrl = TextEditingController();
  final _identifierCtrl      = TextEditingController(text: 'demo-shop');

  XFile? _logoFile;
  bool   _registerMode        = false;
  int    _step                = 1;
  bool   _loading             = false;
  bool   _showPassword        = false;
  bool   _showConfirmPassword = false;
  bool   _isVatRegistered     = true;
  String? _error;

  // ── Étapes dynamiques selon régime fiscal ────────────────────────────────
  // Non assujetti → 3 étapes (MECeF skippée)
  // Assujetti TVA → 4 étapes avec configuration MECeF

  int get _totalSteps => _isVatRegistered ? 4 : 3;

  List<String> get _stepTitles => _isVatRegistered
      ? const [
          'Identite boutique',
          'Informations legales',
          'Configuration MECeF',
          'Compte administrateur',
        ]
      : const [
          'Identite boutique',
          'Informations legales',
          'Compte administrateur',
        ];

  List<String> get _stepSubtitles => _isVatRegistered
      ? const [
          'Nom, identite visuelle et enseigne',
          'IFU, RCCM, coordonnees et regime TVA',
          'Token DGI pour factures normalisees',
          'Email et mot de passe admin',
        ]
      : const [
          'Nom, identite visuelle et enseigne',
          'IFU, RCCM, coordonnees et regime TVA',
          'Email et mot de passe admin',
        ];

  List<IconData> get _stepIcons => _isVatRegistered
      ? const [
          Icons.storefront_rounded,
          Icons.account_balance_rounded,
          Icons.receipt_long_rounded,
          Icons.manage_accounts_rounded,
        ]
      : const [
          Icons.storefront_rounded,
          Icons.account_balance_rounded,
          Icons.manage_accounts_rounded,
        ];

  GlobalKey<FormState> get _currentKey {
    if (!_isVatRegistered) {
      switch (_step) {
        case 1: return _step1Key;
        case 2: return _step2Key;
        default: return _step4Key; // étape 3 = compte admin (MECeF skippée)
      }
    }
    switch (_step) {
      case 1:  return _step1Key;
      case 2:  return _step2Key;
      case 3:  return _step3Key;
      default: return _step4Key;
    }
  }

  @override
  void dispose() {
    _companyCtrl.dispose();
    _commercialNameCtrl.dispose();
    _ifuCtrl.dispose();
    _rccmCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _mecefTokenCtrl.dispose();
    _contactEmailCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _identifierCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ────────────────────────────────────────────────────────────
  void _nextStep() {
    FocusScope.of(context).unfocus();
    if (!_currentKey.currentState!.validate()) return;
    if (_step < _totalSteps) {
      setState(() { _step++; _error = null; });
    } else {
      _submit();
    }
  }

  void _prevStep() {
    FocusScope.of(context).unfocus();
    setState(() { _step--; _error = null; });
  }

  void _setMode(bool registerMode) {
    setState(() { _registerMode = registerMode; _step = 1; _error = null; });
  }

  // ── Soumission ────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      final auth = ref.read(authProvider.notifier);
      if (_registerMode) {
        await auth.register(
          companyName:     _companyCtrl.text.trim(),
          commercialName:  _commercialNameCtrl.text.trim(),
          rccm:            _rccmCtrl.text.trim(),
          ifu:             _ifuCtrl.text.trim(),
          address:         _addressCtrl.text.trim(),
          phone:           _phoneCtrl.text.trim(),
          isVatRegistered: _isVatRegistered,
          mecefToken:      _mecefTokenCtrl.text.trim().isEmpty
              ? null : _mecefTokenCtrl.text.trim(),
          contactEmail:    _contactEmailCtrl.text.trim(),
          email:           _emailCtrl.text.trim(),
          password:        _passwordCtrl.text,
          confirmPassword: _confirmPasswordCtrl.text,
          logoPath:        _logoFile?.path,
        );
      } else {
        if (!_loginKey.currentState!.validate()) {
          setState(() => _loading = false);
          return;
        }
        await auth.login(
          identifier: _identifierCtrl.text.trim(),
          password:   _passwordCtrl.text,
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickLogo() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 88,
    );
    if (picked == null || !mounted) return;
    setState(() => _logoFile = picked);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExitGuard(
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF4F8FD), Color(0xFFEAF3FF), Color(0xFFF7FBFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 430,
                      minHeight: constraints.maxHeight - 40,
                    ),
                    child: IntrinsicHeight(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: _kBorder),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1A0F172A),
                              blurRadius: 40,
                              offset: Offset(0, 20),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [

                            // ── Logo ───────────────────────────────────────
                            Center(
                              child: Container(
                                width: 72, height: 72,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x160F172A),
                                      blurRadius: 24,
                                      offset: Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  'assets/branding/app-logo.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'QuickSellPay',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // ── Switcher ────────────────────────────────────
                            _AuthModeSwitcher(
                              registerMode: _registerMode,
                              onChanged: _setMode,
                            ),
                            const SizedBox(height: 20),

                            // ── Contenu ─────────────────────────────────────
                            if (_registerMode)
                              _buildRegisterContent(theme)
                            else
                              _buildLoginContent(theme),

                            const Spacer(),
                            const SizedBox(height: 16),
                            Text(
                              _registerMode
                                  ? 'Le matricule sera genere automatiquement pour les prochaines connexions.'
                                  : 'Compte demo : demo-shop / AdminDemo123!',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'QuickSellPay : la localisation lors de la verification d\'authenticite doit toujours etre soumise au consentement explicite.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Connexion ─────────────────────────────────────────────────────────────
  Widget _buildLoginContent(ThemeData theme) {
    return Form(
      key: _loginKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Connectez-vous avec le matricule de la boutique et le mot de passe.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          _field(
            controller: _identifierCtrl,
            label: 'Matricule boutique',
            hint: 'Ex: demo-shop',
            icon: Icons.storefront_outlined,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
          ),
          const SizedBox(height: 14),
          _passwordField(
            controller: _passwordCtrl,
            label: 'Mot de passe',
            show: _showPassword,
            onToggle: () => setState(() => _showPassword = !_showPassword),
            action: TextInputAction.done,
            validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 24),
          GradientButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const _Spinner()
                : const Text('Se connecter',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ── Inscription multi-étapes ──────────────────────────────────────────────
  Widget _buildRegisterContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Indicateur d'étapes
        _StepIndicator(step: _step, total: _totalSteps, icons: _stepIcons),
        const SizedBox(height: 20),

        // Titre étape courante
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_stepIcons[_step - 1], color: _kBlue1, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _stepTitles[_step - 1],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    _stepSubtitles[_step - 1],
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Formulaire étape courante
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
                  .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
              child: child,
            ),
          ),
          child: KeyedSubtree(key: ValueKey(_step), child: _buildStepForm()),
        ),

        // Erreur
        if (_error != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(message: _error!),
        ],
        const SizedBox(height: 24),

        // ── Boutons Retour / Suivant ────────────────────────────────────────
        Row(
          children: [
            // Retour — visible dès étape 2
            if (_step > 1) ...[
              OutlinedButton.icon(
                onPressed: _loading ? null : _prevStep,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Retour'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF475569),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  side: const BorderSide(color: _kBorder, width: 1.5),
                ),
              ),
              const SizedBox(width: 12),
            ],
            // Suivant / Créer
            Expanded(
              child: GradientButton(
                onPressed: _loading ? null : _nextStep,
                child: _loading && _step == _totalSteps
                    ? const _Spinner()
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _step < _totalSteps ? 'Suivant' : 'Creer la boutique',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            _step < _totalSteps
                                ? Icons.arrow_forward_rounded
                                : Icons.check_circle_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Formulaires par étape ─────────────────────────────────────────────────
  Widget _buildStepForm() {
    // Non assujetti : étape 3 = compte admin (MECeF ignorée)
    final formStep = (!_isVatRegistered && _step == 3) ? 4 : _step;
    switch (formStep) {
      // ── Étape 1 : Identité boutique ──────────────────────────────────────
      case 1:
        return Form(
          key: _step1Key,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field(
                controller: _companyCtrl,
                label: 'Nom de la boutique',
                icon: Icons.store_outlined,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 14),
              _field(
                controller: _commercialNameCtrl,
                label: 'Nom commercial (enseigne)',
                icon: Icons.badge_outlined,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 14),
              _LogoPickerCard(
                logoFile: _logoFile,
                companyName: _commercialNameCtrl.text,
                onPick: _pickLogo,
              ),
            ],
          ),
        );

      // ── Étape 2 : Informations légales + TVA ─────────────────────────────
      case 2:
        return Form(
          key: _step2Key,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field(
                controller: _ifuCtrl,
                label: 'IFU - Identifiant Fiscal Unique',
                hint: 'Ex: 3201700158911',
                icon: Icons.tag_rounded,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requis';
                  if (v.trim().length != 13) return '13 chiffres requis';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _field(
                controller: _rccmCtrl,
                label: 'RCCM - Registre du Commerce',
                hint: 'Ex: M-RB/LOT/17B 17955',
                icon: Icons.description_outlined,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requis';
                  if (v.trim().length < 3) return '3 caracteres minimum';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _field(
                controller: _addressCtrl,
                label: 'Adresse complete',
                hint: 'Ex: Cadjehoun, Cotonou',
                icon: Icons.location_on_outlined,
                maxLines: 2,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requis';
                  if (v.trim().length < 5) return '5 caracteres minimum';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _field(
                controller: _phoneCtrl,
                label: 'Numero de telephone',
                hint: 'Ex: +229 94 96 16 04',
                icon: Icons.phone_outlined,
                action: TextInputAction.done,
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requis';
                  if (v.trim().length < 6) return '6 caracteres minimum';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Régime TVA
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Regime fiscal TVA',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _VatToggle(
                      value: _isVatRegistered,
                      onChanged: (v) => setState(() {
                        _isVatRegistered = v;
                        // Si on bascule en non-assujetti et qu'on était à l'étape MECeF, reculer
                        if (!v && _step > _totalSteps) _step = _totalSteps;
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isVatRegistered
                          ? 'TVA 18% + AIB [B] 1% apparaitront sur vos factures normalisees MECeF.'
                          : 'Regime simplifie : vos factures seront emises en mode FACTURE PROFORMA, sans TVA.',
                      style: TextStyle(
                        fontSize: 11,
                        color: _isVatRegistered
                            ? const Color(0xFF075985)
                            : const Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      // ── Étape 3 : Configuration MECeF ────────────────────────────────────
      case 3:
        return Form(
          key: _step3Key,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: Color(0xFF0284C7), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Optionnel - Obtenez votre Token DGI sur '
                        'developper.impots.bj apres enregistrement SFE. '
                        'Sans token, les factures sont emises en mode test local.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF075985),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _field(
                controller: _mecefTokenCtrl,
                label: 'Token API DGI MECeF (optionnel)',
                hint: 'Coller le token obtenu sur developper.impots.bj',
                icon: Icons.vpn_key_outlined,
                action: TextInputAction.done,
                validator: (_) => null,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Configure automatiquement par la DGI :',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF166534),
                      ),
                    ),
                    SizedBox(height: 6),
                    _AutoItem(icon: Icons.numbers_rounded,
                        text: 'NIM - Numero du Mecanisme'),
                    _AutoItem(icon: Icons.calculate_outlined,
                        text: 'Compteur sequentiel (ex: 03768/91280 FV)'),
                    _AutoItem(icon: Icons.qr_code_rounded,
                        text: 'Code MECeF/DGI unique par facture'),
                    _AutoItem(icon: Icons.percent_rounded,
                        text: 'BASE IMPOSABLE [B] + TVA 18% (si assujetti)'),
                  ],
                ),
              ),
            ],
          ),
        );

      // ── Étape 4 : Compte administrateur ──────────────────────────────────
      default:
        return Form(
          key: _step4Key,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field(
                controller: _contactEmailCtrl,
                label: 'Email de contact boutique',
                hint: 'visible sur les documents officiels',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requis';
                  if (!_emailPattern.hasMatch(v.trim())) return 'Email invalide';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _field(
                controller: _emailCtrl,
                label: 'Email administrateur',
                hint: 'pour se connecter a QuickSellPay',
                icon: Icons.admin_panel_settings_outlined,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requis';
                  if (!_emailPattern.hasMatch(v.trim())) return 'Email invalide';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _passwordField(
                controller: _passwordCtrl,
                label: 'Mot de passe',
                show: _showPassword,
                onToggle: () => setState(() => _showPassword = !_showPassword),
                action: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requis';
                  if (v.length < 8) return '8 caracteres minimum';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _passwordField(
                controller: _confirmPasswordCtrl,
                label: 'Confirmer le mot de passe',
                show: _showConfirmPassword,
                onToggle: () =>
                    setState(() => _showConfirmPassword = !_showConfirmPassword),
                action: TextInputAction.done,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Confirmation requise';
                  if (v != _passwordCtrl.text)
                    return 'Les mots de passe ne correspondent pas';
                  return null;
                },
              ),
            ],
          ),
        );
    }
  }

  // ── Helpers champs ────────────────────────────────────────────────────────
  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    TextInputAction action = TextInputAction.next,
    TextInputType keyboardType = TextInputType.text,
    List<String>? autofillHints,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      textInputAction: action,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      maxLines: maxLines,
      minLines: 1,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF94A3B8)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kBlue1, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE11D48)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      validator: validator,
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool show,
    required VoidCallback onToggle,
    TextInputAction action = TextInputAction.done,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      textInputAction: action,
      obscureText: !show,
      autofillHints: const [AutofillHints.password],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded,
            size: 20, color: Color(0xFF94A3B8)),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            show ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            size: 20,
            color: const Color(0xFF94A3B8),
          ),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kBlue1, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      validator: validator,
    );
  }
}

// ── Indicateur d'étapes ───────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({
    required this.step,
    required this.total,
    required this.icons,
  });

  final int step;
  final int total;
  final List<IconData> icons;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 1; i <= total; i++) ...[
          _StepDot(index: i, current: step),
          if (i < total)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 2,
                decoration: BoxDecoration(
                  gradient: i < step
                      ? const LinearGradient(colors: [_kBlue1, _kTeal])
                      : null,
                  color: i >= step ? const Color(0xFFE2E8F0) : null,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.index, required this.current});
  final int index;
  final int current;

  @override
  Widget build(BuildContext context) {
    final isDone   = index < current;
    final isActive = index == current;
    final isFuture = index > current;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 36, height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isActive
            ? const LinearGradient(
                colors: [_kBlue2, _kBlue1],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isDone
            ? const Color(0xFF22C1C3)
            : isFuture ? const Color(0xFFF1F5F9) : null,
        border: isFuture
            ? Border.all(color: const Color(0xFFE2E8F0), width: 1.5)
            : null,
        boxShadow: isActive
            ? [BoxShadow(
                color: _kBlue1.withOpacity(0.30),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )]
            : null,
      ),
      alignment: Alignment.center,
      child: isDone
          ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
          : Text(
              '$index',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isActive ? Colors.white : const Color(0xFFCBD5E1),
              ),
            ),
    );
  }
}

// ── Switcher connexion / inscription ─────────────────────────────────────────

class _AuthModeSwitcher extends StatelessWidget {
  const _AuthModeSwitcher({required this.registerMode, required this.onChanged});
  final bool registerMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5FB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              selected: !registerMode,
              icon: Icons.login_rounded,
              label: 'Connexion',
              onTap: () => onChanged(false),
              primaryColor: primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ModeButton(
              selected: registerMode,
              icon: Icons.person_add_alt_1_rounded,
              label: 'Inscription',
              onTap: () => onChanged(true),
              primaryColor: primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.primaryColor,
  });
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18,
                  color: selected ? primaryColor : const Color(0xFF64748B)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Logo picker ───────────────────────────────────────────────────────────────

class _LogoPickerCard extends StatelessWidget {
  const _LogoPickerCard({
    required this.logoFile,
    required this.companyName,
    required this.onPick,
  });
  final XFile? logoFile;
  final String companyName;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = companyName.trim().isEmpty
        ? 'LG'
        : companyName.trim().substring(0, 1).toUpperCase();

    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
              foregroundImage: logoFile != null
                  ? FileImage(File(logoFile!.path)) : null,
              child: logoFile == null
                  ? Text(initials,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Logo de la boutique',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF0F172A))),
                  const SizedBox(height: 3),
                  Text(
                    logoFile == null
                        ? 'Optionnel - tap pour choisir dans la galerie'
                        : logoFile!.name,
                    style: const TextStyle(
                        fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Text('Choisir',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _kBlue1,
                  )),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Toggle TVA ────────────────────────────────────────────────────────────────

class _VatToggle extends StatelessWidget {
  const _VatToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _VatOption(
            selected: value,
            label: 'Assujetti TVA',
            sublabel: 'TVA 18% + AIB [B] 1%',
            onTap: () => onChanged(true),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _VatOption(
            selected: !value,
            label: 'Non assujetti',
            sublabel: 'Regime simplifie',
            onTap: () => onChanged(false),
          ),
        ),
      ],
    );
  }
}

class _VatOption extends StatelessWidget {
  const _VatOption({
    required this.selected,
    required this.label,
    required this.sublabel,
    required this.onTap,
  });
  final bool selected;
  final String label;
  final String sublabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _kBlue1 : const Color(0xFFE2E8F0),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? const Color(0xFF1E40AF) : const Color(0xFF475569),
              ),
            ),
            Text(
              sublabel,
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Item liste verte ──────────────────────────────────────────────────────────

class _AutoItem extends StatelessWidget {
  const _AutoItem({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF16A34A)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 11.5, color: Color(0xFF166534), height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets utilitaires ───────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDA4AF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFE11D48), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Color(0xFFBE123C), fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 22, height: 22,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
}
