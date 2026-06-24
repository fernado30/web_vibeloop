import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ads/ad_service.dart';
import '../../../core/theme/vibe_tokens.dart';
import '../data/groups_repository.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedImageUrl;
  bool _loading = false;
  String? _error;

  static const _coverOptions = [
    'https://images.unsplash.com/photo-1515169067868-5387ec356754?auto=format&fit=crop&w=900&q=80',
    'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?auto=format&fit=crop&w=900&q=80',
    'https://images.unsplash.com/photo-1493711662062-fa541adb3fc8?auto=format&fit=crop&w=900&q=80',
    'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?auto=format&fit=crop&w=900&q=80',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImageUrl == null) {
      _safeSetState(() => _error = 'Selecciona una portada para el grupo.');
      return;
    }

    _safeSetState(() {
      _loading = true;
      _error = null;
    });

    try {
      final existingGroups = await ref.read(groupsRepositoryProvider).fetchMyGroups();
      final shouldShowInterstitial = existingGroups.isNotEmpty;

      final group = await ref.read(groupsControllerProvider.notifier).createGroup(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
            imageUrl: _selectedImageUrl!,
          );
      if (mounted) {
        if (shouldShowInterstitial) {
          await AdService.instance.showInterstitialAfterGroupCreated(waitForDismissal: true);
        }
        if (mounted) {
          context.go('/groups/${group.id}/chat');
        }
      }
    } catch (e) {
      _safeSetState(() => _error = _friendlyCreateGroupError(e));
    } finally {
      _safeSetState(() => _loading = false);
    }
  }

  String _friendlyCreateGroupError(Object error) {
    final message = error.toString();
    if (message.contains('rate_limited_cooldown')) {
      return 'Espera un momento antes de crear otro grupo.';
    }
    if (message.contains('rate_limited')) {
      return 'Has creado demasiados grupos en poco tiempo.';
    }
    if (message.contains('Invalid group name')) {
      return 'El nombre del grupo no es valido.';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    const primaryGradient = LinearGradient(
      colors: [Color(0xFF7D01B1), Color(0xFF3E90FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final scaffoldBackground = isDark ? VibeColors.darkSurface : const Color(0xFFFCF8FB);
    final topBarBackground = isDark ? VibeColors.darkSurfaceSoft.withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.0);
    final cardBackground = isDark ? VibeColors.darkSurfaceSoft.withValues(alpha: 0.96) : Colors.white.withValues(alpha: 0.4);
    final cardBorder = isDark ? VibeColors.darkStroke : Colors.black.withValues(alpha: 0.05);
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final bodyColor = isDark ? const Color(0xFFD3DBEB) : const Color(0xFF667085);
    final labelColor = isDark ? const Color(0xFFB8C4E0) : const Color(0xFF667085);
    final accentColor = isDark ? const Color(0xFFBFD3FF) : const Color(0xFF005AB3);
    final inputHintColor = isDark ? const Color(0xFF8894AC) : const Color(0xFF98A2B3);

    return Scaffold(
      backgroundColor: scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: topBarBackground,
                border: Border(bottom: BorderSide(color: cardBorder)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => context.pop(),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
                      alignment: Alignment.center,
                      child: Icon(Icons.arrow_back_ios_new, color: accentColor),
                    ),
                  ),
                  Text(
                    'Crea tu grupo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: titleColor),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 24 + mediaQuery.padding.bottom),
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1A2240) : const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: cardBorder),
                            ),
                            child: Text(
                              'Paso 1',
                              style: TextStyle(color: accentColor, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'CREA TU GRUPO',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: titleColor),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Personaliza tu espacio. Elige un nombre que resuene y una imagen que capture la esencia de tu comunidad.',
                        style: TextStyle(color: bodyColor, fontSize: 15),
                      ),
                      const SizedBox(height: 18),
                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: cardBackground,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: cardBorder),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'NOMBRE DEL GRUPO',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor),
                                  ),
                                  TextFormField(
                                    controller: _nameController,
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      hintText: 'Ej: Amigos de la Montaña',
                                      hintStyle: TextStyle(color: inputHintColor),
                                    ),
                                    style: TextStyle(color: titleColor),
                                    validator: (value) => (value ?? '').trim().isEmpty ? 'Escribe un nombre' : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: cardBackground,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: cardBorder),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'DESCRIPCIÓN',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor),
                                  ),
                                  TextFormField(
                                    controller: _descriptionController,
                                    keyboardType: TextInputType.multiline,
                                    minLines: 4,
                                    maxLines: 6,
                                    textAlignVertical: TextAlignVertical.top,
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                      hintText:
                                          '¿De qué trata este grupo? Añade detalles para que los miembros sepan qué esperar.',
                                      hintStyle: TextStyle(color: inputHintColor),
                                    ),
                                    style: TextStyle(color: titleColor),
                                    validator: (value) => (value ?? '').trim().isEmpty ? 'Escribe una descripcion' : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Portada sugerida',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: titleColor),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: Text('Ver todas', style: TextStyle(color: accentColor)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 200,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _coverOptions.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final url = _coverOptions[index];
                            final selected = url == _selectedImageUrl;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedImageUrl = url),
                              child: Container(
                                width: 256,
                                clipBehavior: Clip.hardEdge,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.08),
                                      blurRadius: 12,
                                    ),
                                  ],
                                  border: selected
                                      ? Border.all(color: const Color(0xFF7D01B1), width: 2)
                                      : Border.all(color: Colors.transparent),
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(url, fit: BoxFit.cover),
                                    Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [Colors.black54, Colors.transparent],
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 12,
                                      left: 12,
                                      child: Row(
                                        children: [
                                          if (index == 0)
                                            const Icon(Icons.check_circle, color: Colors.white, size: 18)
                                          else
                                            const SizedBox.shrink(),
                                          const SizedBox(width: 6),
                                          Text(
                                            index == 0 ? 'Social' : index == 1 ? 'Creativo' : 'Aventura',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 28),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              backgroundColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 0,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: primaryGradient,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF7D01B1).withValues(alpha: 0.16),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Text(
                                    'CREAR GRUPO',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.chevron_right, color: Colors.white),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Puedes cambiar estos detalles más adelante en los ajustes del grupo.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? const Color(0xFF93A0B8) : const Color(0xFF9AA3B2),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24 + mediaQuery.padding.bottom),
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
}
