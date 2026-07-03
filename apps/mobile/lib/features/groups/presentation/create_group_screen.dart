import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ads/ad_service.dart';
import '../../../core/theme/vibe_tokens.dart';
import '../../../core/widgets/vibe_svg_icon.dart';
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
    } catch (error) {
      _safeSetState(() => _error = _friendlyCreateGroupError(error));
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
      return 'El nombre del grupo no es válido.';
    }
    return message;
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFB9C0D8),
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.7,
      ),
    );
  }

  Widget _buildFieldCard({
    required Widget icon,
    required String hintText,
    required TextEditingController controller,
    required String? Function(String?) validator,
    int maxLines = 1,
    int minLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final isMultiline = maxLines > 1;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(VibeRadii.card),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF101A30).withValues(alpha: 0.92),
            const Color(0xFF0D1528).withValues(alpha: 0.88),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(VibeRadii.card),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, isMultiline ? 18 : 16, 20, isMultiline ? 18 : 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  alignment: Alignment.center,
                  child: icon,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    maxLines: maxLines,
                    minLines: minLines,
                    keyboardType: keyboardType,
                    cursorColor: Colors.white,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      height: 1.35,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: hintText,
                      hintMaxLines: isMultiline ? 3 : 1,
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.54),
                        fontSize: isMultiline ? 17 : 18,
                        fontWeight: FontWeight.w400,
                        height: 1.35,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    validator: validator,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverCard({
    required String url,
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 236,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? const Color(0xFF19B8FF) : Colors.white.withValues(alpha: 0.12),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? const Color(0xFF7A3CFF).withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.22),
              blurRadius: selected ? 28 : 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFF101A30),
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_rounded, color: Colors.white54, size: 32),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0xFF050816),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.62],
                  ),
                ),
              ),
              if (selected)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF7F5BFF).withValues(alpha: 0.65), width: 1.5),
                  ),
                ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 16,
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.08, -0.94),
          radius: 1.35,
          colors: [
            Color(0xFF6E18C8),
            Color(0xFF16234D),
            Color(0xFF040916),
          ],
          stops: [0.0, 0.24, 0.8],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;
    const buttonGradient = LinearGradient(
      colors: [
        Color(0xFF246BFF),
        Color(0xFF7E2DFF),
        Color(0xFFFF4DB0),
      ],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF040916),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildBackground()),
            Positioned(
              top: -110,
              right: -70,
              child: _GlowBlob(
                size: 260,
                colors: [
                  const Color(0xFFFF4BC6).withValues(alpha: 0.56),
                  const Color(0xFF6C2CFF).withValues(alpha: 0.18),
                  Colors.transparent,
                ],
              ),
            ),
            Positioned(
              bottom: -160,
              left: -120,
              child: _GlowBlob(
                size: 320,
                colors: [
                  const Color(0xFF256BFF).withValues(alpha: 0.22),
                  const Color(0xFF256BFF).withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
            Positioned(
              top: 18,
              left: 18,
              child: _FloatingBackButton(onTap: () => context.pop()),
            ),
            Positioned.fill(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(28, 24, 28, 20 + bottomPadding),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 660),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 30),
                        Center(
                          child: Column(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  Positioned(
                                    top: -18,
                                    right: -42,
                                    child: Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 26,
                                      color: const Color(0xFF7C4DFF).withValues(alpha: 0.95),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 10,
                                    left: -46,
                                    child: Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 22,
                                      color: const Color(0xFF4EA5FF).withValues(alpha: 0.95),
                                    ),
                                  ),
                                  Container(
                                    width: 126,
                                    height: 126,
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFF2D7CFF),
                                          Color(0xFF8C3BFF),
                                          Color(0xFFFF4FB8),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFF071021),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                                      ),
                                      child: const Center(
                                        child: VibeSvgIcon(
                                          VibeAssetIcons.group,
                                          size: 54,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 28),
                              const Text(
                                'Crea tu grupo',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 46,
                                  height: 1.0,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.2,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Personaliza tu espacio',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.62),
                                  fontSize: 24,
                                  height: 1.1,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: -0.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 52),
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildLabel('NOMBRE DEL GRUPO'),
                              const SizedBox(height: 14),
                              _buildFieldCard(
                                icon: ShaderMask(
                                  shaderCallback: (bounds) => buttonGradient.createShader(bounds),
                                  child: const Icon(Icons.groups_rounded, color: Colors.white, size: 28),
                                ),
                                hintText: 'Ej: Amigos de la Montaña',
                                controller: _nameController,
                                validator: (value) => (value ?? '').trim().isEmpty ? 'Escribe un nombre' : null,
                              ),
                              const SizedBox(height: 34),
                              _buildLabel('DESCRIPCIÓN'),
                              const SizedBox(height: 14),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(VibeRadii.card),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF101A30).withValues(alpha: 0.92),
                                      const Color(0xFF0D1528).withValues(alpha: 0.88),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.22),
                                      blurRadius: 32,
                                      offset: const Offset(0, 16),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(VibeRadii.card),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 38,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.04),
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                            ),
                                            alignment: Alignment.center,
                                            child: ShaderMask(
                                              shaderCallback: (bounds) => buttonGradient.createShader(bounds),
                                              child: const Icon(Icons.edit_rounded, color: Colors.white, size: 24),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: TextFormField(
                                              controller: _descriptionController,
                                              keyboardType: TextInputType.multiline,
                                              minLines: 4,
                                              maxLines: 6,
                                              cursorColor: Colors.white,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w400,
                                                height: 1.4,
                                              ),
                                              textAlignVertical: TextAlignVertical.top,
                                              decoration: InputDecoration(
                                                border: InputBorder.none,
                                                isDense: true,
                                                hintText:
                                                    '¿De qué trata este grupo? Añade detalles para que los miembros sepan qué esperar.',
                                                hintStyle: TextStyle(
                                                  color: Colors.white.withValues(alpha: 0.54),
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w400,
                                                  height: 1.4,
                                                ),
                                              ),
                                              validator: (value) =>
                                                  (value ?? '').trim().isEmpty ? 'Escribe una descripción' : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _descriptionController,
                                  builder: (context, value, child) {
                                    return Text(
                                      '${value.text.length}/120',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.60),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 24),
                              Divider(color: Colors.white.withValues(alpha: 0.10), height: 1),
                              const SizedBox(height: 28),
                              _buildLabel('PORTADA DEL GRUPO'),
                              const SizedBox(height: 14),
                              SizedBox(
                                height: 290,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: _coverOptions.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 18),
                                  itemBuilder: (context, index) {
                                    final url = _coverOptions[index];
                                    final title = index == 0 ? 'Social' : index == 1 ? 'Creativo' : 'Aventura';
                                    final selected = url == _selectedImageUrl;
                                    return _buildCoverCard(
                                      url: url,
                                      title: title,
                                      selected: selected,
                                      onTap: () => setState(() => _selectedImageUrl = url),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 38),
                              Opacity(
                                opacity: _loading ? 0.72 : 1,
                                child: InkWell(
                                  onTap: _loading ? null : _submit,
                                  borderRadius: BorderRadius.circular(24),
                                  child: Container(
                                    height: 78,
                                    decoration: BoxDecoration(
                                      gradient: buttonGradient,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF3B7BFF).withValues(alpha: 0.30),
                                          blurRadius: 26,
                                          offset: const Offset(0, 12),
                                        ),
                                        BoxShadow(
                                          color: const Color(0xFFF04BB7).withValues(alpha: 0.18),
                                          blurRadius: 30,
                                          offset: const Offset(0, 14),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 180),
                                      child: _loading
                                          ? const SizedBox(
                                              key: ValueKey('loading'),
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.4,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                          : const Row(
                                              key: ValueKey('cta'),
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'CREAR GRUPO',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 23,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: -0.3,
                                                  ),
                                                ),
                                                SizedBox(width: 18),
                                                Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 22),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.lock_outline_rounded, color: Color(0xFF9D39FF), size: 24),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Tu grupo será privado por defecto',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.62),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 18),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFFF6B8A),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(height: 34 + bottomPadding),
                        Center(
                          child: Container(
                            width: 140,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.90),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ],
                    ),
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

class _FloatingBackButton extends StatelessWidget {
  const _FloatingBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF121A2E).withValues(alpha: 0.82),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 40),
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({
    required this.size,
    required this.colors,
  });

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final stops = colors.length == 3 ? const [0.0, 0.45, 1.0] : null;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: colors,
          stops: stops,
        ),
      ),
    );
  }
}
