import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/auth_repository.dart';
import 'auth_visuals.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static final Uri _privacyUrl = Uri.parse('https://web-vibeloop-legal.vercel.app/privacy');
  static const String _privacyPolicyVersion = '2026-07-17';
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _privacyAccepted = false;
  String? _error;

  @override
  void dispose() {
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
    if (!_privacyAccepted) {
      _safeSetState(() => _error = 'Debes autorizar el tratamiento de tus datos personales para continuar.');
      return;
    }
    if (!mounted) return;
    _safeSetState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref.read(authRepositoryProvider).signInWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (response.user != null) {
        await ref.read(authRepositoryProvider).recordPrivacyConsent(
              policyVersion: _privacyPolicyVersion,
              user: response.user!,
            );
      }
      if (mounted) context.go('/groups');
    } on AuthException catch (e) {
      _safeSetState(() => _error = e.message);
    } catch (e) {
      _safeSetState(() => _error = e.toString());
    } finally {
      _safeSetState(() => _loading = false);
    }
  }

  Future<void> _signInGoogle() async {
    if (!mounted) return;
    if (!_privacyAccepted) {
      _safeSetState(() => _error = 'Debes autorizar el tratamiento de tus datos personales para continuar.');
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
      title: 'Nadien',
      subtitle: 'Vuelve a tu comunidad con una sesión segura y rápida.',
      fields: [
        Form(
          key: _formKey,
          child: Column(
            children: [
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
                validator: (value) => (value ?? '').length < 6 ? 'Mínimo 6 caracteres' : null,
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
      primaryLabel: 'Iniciar sesión',
      primaryIcon: const Icon(Icons.arrow_forward_rounded, size: 28),
      onPrimaryPressed: _submit,
      googleLabel: 'Continuar con Google',
      onGooglePressed: _signInGoogle,
      errorText: _error,
      loading: _loading,
      footer: AuthFooterLink(
        prompt: null,
        actionLabel: 'Crear cuenta',
        onPressed: () => context.push('/register'),
      ),
    );
  }
}
