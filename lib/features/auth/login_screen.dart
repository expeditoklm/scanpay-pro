import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/widgets/gradient_button.dart';
import 'auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static final RegExp _emailPattern =
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final _companyCtrl = TextEditingController(text: 'Boutique Demo');
  final _commercialNameCtrl = TextEditingController(text: 'Boutique Demo');
  final _rccmCtrl = TextEditingController();
  final _ifuCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _contactEmailCtrl = TextEditingController();
  final _identifierCtrl = TextEditingController(text: 'demo-shop');
  final _emailCtrl = TextEditingController(text: 'admin@demo.tpe-qr.com');
  final _passwordCtrl = TextEditingController(text: 'AdminDemo123!');
  final _confirmPasswordCtrl = TextEditingController();

  XFile? _logoFile;
  bool _registerMode = false;
  bool _loading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  String? _error;

  @override
  void dispose() {
    _companyCtrl.dispose();
    _commercialNameCtrl.dispose();
    _rccmCtrl.dispose();
    _ifuCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _contactEmailCtrl.dispose();
    _identifierCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = ref.read(authProvider.notifier);
      if (_registerMode) {
        await auth.register(
          companyName: _companyCtrl.text.trim(),
          commercialName: _commercialNameCtrl.text.trim(),
          rccm: _rccmCtrl.text.trim(),
          ifu: _ifuCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          contactEmail: _contactEmailCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          confirmPassword: _confirmPasswordCtrl.text,
          logoPath: _logoFile?.path,
        );
      } else {
        await auth.login(
          identifier: _identifierCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
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

  void _setMode(bool registerMode) {
    setState(() {
      _registerMode = registerMode;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
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
            builder: (context, constraints) {
              return SingleChildScrollView(
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
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFFFFF), Color(0xFFF6FAFF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: const Color(0xFFD7E2F2)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1A0F172A),
                              blurRadius: 40,
                              offset: Offset(0, 20),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Align(
                                child: Container(
                                  width: 88,
                                  height: 88,
                                  clipBehavior: Clip.antiAlias,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(26),
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
                              const SizedBox(height: 16),
                              Text(
                                'QuickSellPay',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.08),
                                ),
                                child: Text(
                                  'Une caisse elegante, rapide et connectee pour les boutiques nouvelle generation.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _registerMode
                                    ? 'Creez votre boutique QuickSellPay, ajoutez son identite legale et son logo.'
                                    : 'Connectez-vous avec le matricule de la boutique et le mot de passe.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 24),
                              _AuthModeSwitcher(
                                registerMode: _registerMode,
                                onChanged: _setMode,
                              ),
                              const SizedBox(height: 20),
                              if (_registerMode) ...[
                                TextFormField(
                                  controller: _companyCtrl,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Nom de la boutique',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (!_registerMode) return null;
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Requis';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _commercialNameCtrl,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Nom commercial',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (!_registerMode) return null;
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Requis';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                _LogoPickerCard(
                                  logoFile: _logoFile,
                                  companyName: _commercialNameCtrl.text,
                                  onPick: _pickLogo,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _rccmCtrl,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Numero RCCM',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (!_registerMode) return null;
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Requis';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _ifuCtrl,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'IFU',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (!_registerMode) return null;
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Requis';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _addressCtrl,
                                  textInputAction: TextInputAction.next,
                                  minLines: 2,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: 'Adresse complete',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (!_registerMode) return null;
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Requis';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _phoneCtrl,
                                  textInputAction: TextInputAction.next,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    labelText: 'Numero de telephone',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (!_registerMode) return null;
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Requis';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _contactEmailCtrl,
                                  textInputAction: TextInputAction.next,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Email de contact boutique',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (!_registerMode) return null;
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Requis';
                                    }
                                    if (!_emailPattern.hasMatch(value.trim())) {
                                      return 'Email invalide';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _emailCtrl,
                                  textInputAction: TextInputAction.next,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.email],
                                  decoration: const InputDecoration(
                                    labelText: 'Email administrateur',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (!_registerMode) return null;
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Requis';
                                    }
                                    if (!_emailPattern
                                        .hasMatch(value.trim())) {
                                      return 'Email invalide';
                                    }
                                    return null;
                                  },
                                ),
                              ] else ...[
                                TextFormField(
                                  controller: _identifierCtrl,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.username],
                                  decoration: const InputDecoration(
                                    labelText: 'Matricule boutique',
                                    hintText: 'Ex: demo-shop',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Requis';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordCtrl,
                                textInputAction: _registerMode
                                    ? TextInputAction.next
                                    : TextInputAction.done,
                                obscureText: !_showPassword,
                                autofillHints: const [AutofillHints.password],
                                decoration: InputDecoration(
                                  labelText: 'Mot de passe',
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _showPassword = !_showPassword;
                                      });
                                    },
                                    icon: Icon(
                                      _showPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Requis';
                                  }
                                  if (_registerMode &&
                                      value.trim().length < 8) {
                                    return '8 caracteres minimum';
                                  }
                                  return null;
                                },
                              ),
                              if (_registerMode) ...[
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _confirmPasswordCtrl,
                                  textInputAction: TextInputAction.done,
                                  obscureText: !_showConfirmPassword,
                                  autofillHints: const [AutofillHints.password],
                                  decoration: InputDecoration(
                                    labelText: 'Confirmer le mot de passe',
                                    border: const OutlineInputBorder(),
                                    suffixIcon: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _showConfirmPassword =
                                              !_showConfirmPassword;
                                        });
                                      },
                                      icon: Icon(
                                        _showConfirmPassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (!_registerMode) return null;
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Confirmation requise';
                                    }
                                    if (value != _passwordCtrl.text) {
                                      return 'Les mots de passe ne correspondent pas';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.errorContainer
                                        .withOpacity(0.45),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              GradientButton(
                                onPressed: _loading ? null : _submit,
                                child: _loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        _registerMode
                                            ? 'Creer la boutique'
                                            : 'Se connecter',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _registerMode
                                    ? 'Le matricule de boutique sera genere automatiquement pour les prochaines connexions QuickSellPay.'
                                    : 'Compte demo : demo-shop / AdminDemo123!',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const Spacer(),
                              const SizedBox(height: 16),
                              Text(
                                'QuickSellPay : la localisation lors de la verification d authenticite doit toujours etre soumise au consentement explicite.',
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
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AuthModeSwitcher extends StatelessWidget {
  const _AuthModeSwitcher({
    required this.registerMode,
    required this.onChanged,
  });

  final bool registerMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5FB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD7E2F2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              selected: !registerMode,
              icon: Icons.login,
              label: 'Connexion',
              onTap: () => onChanged(false),
              primaryColor: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ModeButton(
              selected: registerMode,
              icon: Icons.person_add_alt_1,
              label: 'Inscription',
              onTap: () => onChanged(true),
              primaryColor: theme.colorScheme.primary,
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
              Icon(
                icon,
                size: 18,
                color: selected ? primaryColor : const Color(0xFF64748B),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD7E2F2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor:
                      theme.colorScheme.primary.withValues(alpha: 0.12),
                  foregroundImage:
                      logoFile != null ? FileImage(File(logoFile!.path)) : null,
                  child: logoFile == null
                      ? Text(
                          initials,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Logo QuickSellPay',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        logoFile == null
                            ? 'Ajoutez le logo maintenant. Un visuel par defaut sera utilise sinon.'
                            : logoFile!.name,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(
                onPressed: onPick,
                child: const Text('Choisir un logo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
