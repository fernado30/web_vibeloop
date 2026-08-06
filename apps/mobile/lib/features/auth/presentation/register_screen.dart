import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/vibe_tokens.dart';
import '../data/auth_repository.dart';
import '../domain/age_eligibility.dart';
import 'auth_visuals.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  static final Uri _privacyUrl = Uri.parse('https://web-legal-nadie.vercel.app/privacy');
  static final Uri _termsUrl = Uri.parse('https://web-legal-nadie.vercel.app/terms');
  static const String _privacyPolicyVersion = '2026-07-22';
  static const String _termsVersion = '2026-07-22';
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _privacyAccepted = false;
  bool _termsAccepted = false;
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
    if (!_termsAccepted) {
      _safeSetState(() => _error = 'Debes leer y aceptar expresamente los Términos de Servicio para registrarte.');
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
            termsAccepted: _termsAccepted,
            termsVersion: _termsVersion,
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
    if (!_termsAccepted) {
      _safeSetState(() => _error = 'Debes leer y aceptar expresamente los Términos de Servicio para registrarte.');
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
      final event = await Supabase.instance.client.auth.onAuthStateChange
          .firstWhere((event) => event.session != null);
      if (_birthDate != null) {
        await ref.read(authRepositoryProvider).completeAgeVerification(
              birthDate: _birthDate!,
              privacyPolicyVersion: _privacyPolicyVersion,
              termsVersion: _termsVersion,
              termsAccepted: _termsAccepted,
            );
      } else {
        await ref.read(authRepositoryProvider).recordPrivacyConsent(
              policyVersion: _privacyPolicyVersion,
              user: event.session!.user,
              termsAccepted: _termsAccepted,
              termsVersion: _termsVersion,
            );
      }
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
      subtitle: 'Únete a Nadie y conecta con tu comunidad.',
      fields: [
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
              const SizedBox(height: 14),
              AuthDatePickerField(
                selectedDate: _birthDate,
                enabled: !_loading,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                    initialDate: _birthDate ?? DateTime(DateTime.now().year - 13),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(
                            primary: VibeColors.primaryViolet,
                            onPrimary: Colors.white,
                            surface: Colors.white,
                            onSurface: VibeColors.primaryDeepBlue,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) _safeSetState(() => _birthDate = picked);
                },
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _emailController,
                label: 'Correo electrónico',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (value) => value == null || !value.contains('@') ? 'Ingresa un email válido' : null,
              ),
              const SizedBox(height: 14),
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
              AuthConsentCheckbox(
                value: _privacyAccepted,
                enabled: !_loading,
                onChanged: (value) => _safeSetState(() => _privacyAccepted = value ?? false),
                prefixText: 'Autorizo el tratamiento de mis datos personales conforme a la ',
                linkText: 'Política de Tratamiento de Datos',
                onLinkTap: () => launchUrl(_privacyUrl, mode: LaunchMode.externalApplication),
                suffixText: '.',
              ),
              const SizedBox(height: 10),
              AuthConsentCheckbox(
                value: _termsAccepted,
                enabled: !_loading,
                onChanged: (value) => _safeSetState(() => _termsAccepted = value ?? false),
                prefixText: 'He leído y acepto expresamente los ',
                linkText: 'Términos de Servicio',
                onLinkTap: () => launchUrl(_termsUrl, mode: LaunchMode.externalApplication),
                suffixText: ' de Nadie.',
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
