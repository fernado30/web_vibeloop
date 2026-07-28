import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/auth_repository.dart';
import '../domain/age_eligibility.dart';
import 'auth_visuals.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  static final Uri _privacyUrl = Uri.parse('https://web-vibeloop-legal.vercel.app/privacy');
  static const String _privacyPolicyVersion = '2026-07-17';
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _privacyAccepted = false;
  DateTime? _birthDate;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthDate == null) {
      _safeSetState(() => _error = 'Selecciona tu fecha de nacimiento para verificar tu edad.');
      return;
    }
    if (isUnder13(_birthDate!)) {
      _safeSetState(() => _error = ageGateMessage());
      return;
    }
    if (!_privacyAccepted) {
      _safeSetState(() => _error = 'Debes autorizar el tratamiento de tus datos personales para registrarte.');
      return;
    }
    _safeSetState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signUpWithEmail(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            birthDate: _birthDate!,
            privacyPolicyVersion: _privacyPolicyVersion,
          );
      if (mounted) context.go('/groups');
    } catch (e) {
      _safeSetState(() => _error = e.toString());
    } finally {
      _safeSetState(() => _loading = false);
    }
  }

  Future<void> _signInGoogle() async {
    if (!mounted) return;
    if (_birthDate == null || isUnder13(_birthDate!)) {
      _safeSetState(() => _error = _birthDate == null
          ? 'Selecciona tu fecha de nacimiento para verificar tu edad.'
          : ageGateMessage());
      return;
    }
    if (!_privacyAccepted) {
      _safeSetState(() => _error = 'Debes autorizar el tratamiento de tus datos personales para registrarte.');
      return;
    }
    _safeSetState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'vibeloop://auth-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      // OAuth returns through the auth callback. Keep the same consent evidence
      // for accounts created with Google as for email/password registration.
      final event = await Supabase.instance.client.auth.onAuthStateChange
          .firstWhere((event) => event.session != null);
      await ref.read(authRepositoryProvider).recordPrivacyConsent(
            policyVersion: _privacyPolicyVersion,
            user: event.session!.user,
          );
    } catch (e) {
      _safeSetState(() => _error = e.toString());
    } finally {
      _safeSetState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenShell(
      title: 'Crea tu cuenta',
      subtitle: 'Únete a Nadien y conecta con tu comunidad.',
      fields: [
        const Text('Nadien no está dirigido a menores de 13 años.'),
        const SizedBox(height: 12),
        Form(
          key: _formKey,
          child: Column(
            children: [
              AuthTextField(
                controller: _nameController,
                label: 'Nombre',
                icon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                validator: (value) => (value ?? '').trim().isEmpty ? 'Ingresa tu nombre' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cake_outlined),
                title: Text(_birthDate == null
                    ? 'Fecha de nacimiento'
                    : 'Fecha de nacimiento: ${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}'),
                subtitle: const Text('Solo verificamos que tengas al menos 13 años; no guardamos la fecha.'),
                onTap: _loading ? null : () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                    initialDate: _birthDate ?? DateTime(DateTime.now().year - 13),
                  );
                  if (picked != null) _safeSetState(() => _birthDate = picked);
                },
              ),
              const SizedBox(height: 4),
              AuthTextField(
                controller: _emailController,
                label: 'Correo electrónico',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (value) => value == null || !value.contains('@') ? 'Ingresa un email válido' : null,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _passwordController,
                label: 'Contraseña',
                icon: Icons.lock_outline_rounded,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: _loading ? null : _submit,
                validator: (value) => (value ?? '').length < 8 ? 'Mínimo 8 caracteres' : null,
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _privacyAccepted,
                onChanged: _loading ? null : (value) => _safeSetState(() => _privacyAccepted = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                title: Wrap(
                  children: [
                    const Text('Autorizo de manera previa, expresa e informada el tratamiento de mis datos personales conforme a la '),
                    GestureDetector(
                      onTap: () => launchUrl(_privacyUrl, mode: LaunchMode.externalApplication),
                      child: const Text(
                        'Política de Tratamiento de Datos',
                        style: TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Text('.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      primaryLabel: 'Registrarme',
      primaryIcon: const Icon(Icons.auto_awesome_rounded, size: 27),
      onPrimaryPressed: _submit,
      googleLabel: 'Registrarme con Google',
      onGooglePressed: _signInGoogle,
      errorText: _error,
      loading: _loading,
      footer: AuthFooterLink(
        prompt: '¿Ya tengo cuenta?',
        actionLabel: 'Iniciar sesión',
        onPressed: () => context.push('/login'),
      ),
    );
  }
}
