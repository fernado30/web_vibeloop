import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ads/ad_service.dart';
import '../../../core/theme/vibe_tokens.dart';
import '../../../core/widgets/vibe_ui.dart';
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
    // Réplica fiel del HTML/CSS proporcionado
    final primaryGradient = const LinearGradient(
      colors: [Color(0xFF7D01B1), Color(0xFF3E90FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFCF8FB),
      body: SafeArea(
        child: Column(
          children: [
            // Top navigation bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.0),
                border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.05))),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      child: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF005AB3)),
                    ),
                  ),
                  const Text('Crea tu grupo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    children: [
                      // Step indicator
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.black.withOpacity(0.05)),
                            ),
                            child: const Text('Paso 1', style: TextStyle(color: Color(0xFF005AB3), fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Header
                      const Text('CREA TU GRUPO', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      const Text(
                        'Personaliza tu espacio. Elige un nombre que resuene y una imagen que capture la esencia de tu comunidad.',
                        style: TextStyle(color: Color(0xFF667085), fontSize: 15),
                      ),
                      const SizedBox(height: 18),

                      // Inputs
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Name
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.black.withOpacity(0.05)),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('NOMBRE DEL GRUPO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF667085))),
                                  TextFormField(
                                    controller: _nameController,
                                    decoration: const InputDecoration(border: InputBorder.none, hintText: 'Ej: Amigos de la Montaña'),
                                    validator: (value) => (value ?? '').trim().isEmpty ? 'Escribe un nombre' : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Description
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.black.withOpacity(0.05)),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('DESCRIPCIÓN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF667085))),
                                  TextFormField(
                                    controller: _descriptionController,
                                    decoration: const InputDecoration(border: InputBorder.none, hintText: '¿De qué trata este grupo? Añade detalles para que los miembros sepan qué esperar.'),
                                    maxLines: 3,
                                    validator: (value) => (value ?? '').trim().isEmpty ? 'Escribe una descripcion' : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      // Cover suggestion header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Portada sugerida', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          TextButton(onPressed: () {}, child: const Text('Ver todas', style: TextStyle(color: Color(0xFF3E90FF)))),
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
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12)],
                                  border: selected ? Border.all(color: const Color(0xFF7D01B1), width: 2) : Border.all(color: Colors.transparent),
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(url, fit: BoxFit.cover),
                                    Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black54, Colors.transparent]))),
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
                                          Text(index == 0 ? 'Social' : index == 1 ? 'Creativo' : 'Aventura', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
                      // CTA
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
                              decoration: BoxDecoration(gradient: primaryGradient, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: const Color(0xFF7D01B1).withOpacity(0.16), blurRadius: 20, offset: const Offset(0, 10))]),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('CREAR GRUPO', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.chevron_right, color: Colors.white),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text('Puedes cambiar estos detalles más adelante en los ajustes del grupo.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF9AA3B2), fontSize: 13)),
                        ],
                      ),

                      const SizedBox(height: 24),
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
