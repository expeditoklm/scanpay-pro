import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');
  final _formKey = GlobalKey<FormState>();
  final _companyCtrl = TextEditingController(text: 'Boutique Demo');
  final _identifierCtrl = TextEditingController(text: 'demo-shop');
  final _emailCtrl = TextEditingController(text: 'admin@demo.tpe-qr.com');
  final _passwordCtrl = TextEditingController(text: 'AdminDemo123!');
  final _confirmPasswordCtrl = TextEditingController();
  bool _registerMode = false;
  bool _loading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  String? _error;

  @override
  void dispose() {
    _companyCtrl.dispose();
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
          companyName: _companyCtrl.text,
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
          confirmPassword: _confirmPasswordCtrl.text,
        );
      } else {
        await auth.login(
          identifier: _identifierCtrl.text,
          password: _passwordCtrl.text,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.point_of_sale,
                          size: 64,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'TPE QR SaaS',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _registerMode
                              ? 'Cree une boutique puis confirme le mot de passe pour activer le compte administrateur.'
                              : 'Connecte-toi avec le matricule de la boutique et le mot de passe administrateur.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 28),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment<bool>(
                              value: false,
                              label: Text('Connexion'),
                              icon: Icon(Icons.login),
                            ),
                            ButtonSegment<bool>(
                              value: true,
                              label: Text('Inscription'),
                              icon: Icon(Icons.person_add_alt_1),
                            ),
                          ],
                          selected: {_registerMode},
                          onSelectionChanged: (values) {
                            setState(() {
                              _registerMode = values.first;
                              _error = null;
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                        if (_registerMode) ...[
                          TextFormField(
                            controller: _companyCtrl,
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
                            controller: _emailCtrl,
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
                              if (!_emailPattern.hasMatch(value.trim())) {
                                return 'Email invalide';
                              }
                              return null;
                            },
                          ),
                        ] else
                          TextFormField(
                            controller: _identifierCtrl,
                            autofillHints: const [AutofillHints.username],
                            decoration: const InputDecoration(
                              labelText: 'Matricule boutique',
                              hintText: 'Ex: demo-shop',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? 'Requis'
                                    : null,
                          ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: !_showPassword,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: 'Mot de passe',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() => _showPassword = !_showPassword);
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
                            if (_registerMode && value.trim().length < 8) {
                              return '8 caracteres minimum';
                            }
                            return null;
                          },
                        ),
                        if (_registerMode) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordCtrl,
                            obscureText: !_showConfirmPassword,
                            autofillHints: const [AutofillHints.password],
                            decoration: InputDecoration(
                              labelText: 'Confirmer le mot de passe',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _showConfirmPassword = !_showConfirmPassword;
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
                          Text(
                            _error!,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _registerMode
                                      ? 'Creer la boutique'
                                      : 'Se connecter',
                                ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _registerMode
                              ? 'Le matricule de boutique sera le code interne utilise pour la connexion.'
                              : 'Compte demo pret a l emploi : demo-shop / AdminDemo123!',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Mentions legales : lors de la verification d authenticite, la localisation ne doit etre collectee qu avec consentement explicite. Elle sert a la securite, a la tracabilite et aux statistiques antifraude.',
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
    );
  }
}
