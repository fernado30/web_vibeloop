import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/vibe_tokens.dart';
import '../../../core/widgets/vibe_ui.dart';
import '../data/auth_repository.dart';
import 'auth_visuals.dart';

class OauthAgeGateScreen extends ConsumerStatefulWidget {
  const OauthAgeGateScreen({super.key});

  @override
  ConsumerState<OauthAgeGateScreen> createState() => _OauthAgeGateScreenState();
}

class _OauthAgeGateScreenState extends ConsumerState<OauthAgeGateScreen> {
  final _privacyPolicyVersion = '2026-07-22';
  final _termsVersion = '2026-07-22';

  DateTime? _birthDate;
  bool _privacyAccepted = false;
  bool _termsAccepted = false;
  bool _loading = false;
  String? _error;

  static final Uri _privacyUrl = Uri.parse('https://web-legal-nadie.vercel.app/privacy');
  static final Uri _termsUrl = Uri.parse('https://web-legal-nadie.vercel.app/terms');

  bool get _isAtLeast13 {
    final date = _birthDate;
    if (date == null) return false;
    final now = DateTime.now();
    var age = now.year - date.year;
    if (now.month < date.month || (now.month == date.month && now.day < date.day)) {
      age--;
    }
    return age >= 13;
  }

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();
    final initialDate = _birthDate ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Selecciona tu fecha de nacimiento',
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _error = null;
      });
    }
  }

  Future<void> _openUrl(Uri url) async {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _submitVerification() async {
    if (_birthDate == null) {
      setState(() => _error = 'Por favor selecciona tu fecha de nacimiento.');
      return;
    }
    if (!_isAtLeast13) {
      setState(() => _error = 'Nadie no está disponible para menores de 13 años (cumplimiento COPPA).');
      return;
    }
    if (!_privacyAccepted) {
      setState(() => _error = 'Debes autorizar la política de privacidad para continuar.');
      return;
    }
    if (!_termsAccepted) {
      setState(() => _error = 'Debes leer y aceptar los Términos de Servicio para continuar.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(authRepositoryProvider).completeAgeVerification(
            birthDate: _birthDate!,
            privacyPolicyVersion: _privacyPolicyVersion,
            termsVersion: _termsVersion,
            termsAccepted: _termsAccepted,
          );

      if (!mounted) return;
      context.go('/groups');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final birthDateStr = _birthDate == null
        ? 'Seleccionar fecha de nacimiento'
        : '${_birthDate!.day.toString().padLeft(2, '0')}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.year}';

    return AuthScreenShell(
      title: 'Verificación de Edad',
      subtitle: 'Para completar tu registro con Google en Nadie, necesitamos confirmar tu edad y consentimiento legal.',
      fields: [
        const Text(
          'Nadie no está dirigido a menores de 13 años.',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _loading ? null : _selectBirthDate,
          icon: const Icon(Icons.cake_outlined, size: 20),
          label: Text(birthDateStr),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
          ),
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          value: _privacyAccepted,
          onChanged: _loading ? null : (val) => setState(() => _privacyAccepted = val ?? false),
          title: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Acepto la '),
              GestureDetector(
                onTap: () => _openUrl(_privacyUrl),
                child: Text(
                  'Política de Privacidad',
                  style: TextStyle(
                    color: VibeColors.primaryViolet,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const Text(' (v2026-07-22)'),
            ],
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          value: _termsAccepted,
          onChanged: _loading ? null : (val) => setState(() => _termsAccepted = val ?? false),
          title: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Acepto los '),
              GestureDetector(
                onTap: () => _openUrl(_termsUrl),
                child: Text(
                  'Términos de Servicio',
                  style: TextStyle(
                    color: VibeColors.primaryViolet,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const Text(' (v2026-07-22)'),
            ],
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(color: VibeColors.dangerRed, fontWeight: FontWeight.bold),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _loading ? null : _submitVerification,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Completar y Continuar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ],
    );
  }
}
