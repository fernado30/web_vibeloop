import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/ads/vibe_loop_banner_ad.dart';
import '../../../core/widgets/vibe_svg_icon.dart';
import '../../../core/widgets/vibe_ui.dart';
import '../data/groups_repository.dart';
import '../domain/group_model.dart';
import '../domain/group_photo_model.dart';

class GroupPhotosScreen extends ConsumerStatefulWidget {
  const GroupPhotosScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupPhotosScreen> createState() => _GroupPhotosScreenState();
}

class _GroupPhotosScreenState extends ConsumerState<GroupPhotosScreen> {
  late final Stream<List<GroupPhotoModel>> _photosStream;
  late final Future<InviteLinks> _inviteLinksFuture;
  late final Future<GroupModel> _groupFuture;
  final GlobalKey _coverKey = GlobalKey();
  bool _isPreparingShare = false;
  final Set<String> _deletingPhotoIds = <String>{};
  final Set<String> _hiddenPhotoIds = <String>{};

  @override
  void initState() {
    super.initState();
    _photosStream = ref.read(groupsRepositoryProvider).watchGroupPhotos(widget.groupId);
    _inviteLinksFuture = ref.read(groupsRepositoryProvider).generateInviteLinks(widget.groupId);
    _groupFuture = ref.read(groupsRepositoryProvider).getGroupById(widget.groupId);
  }

  Future<void> _addPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
    );

    if (image == null) return;

    try {
      await ref.read(groupsRepositoryProvider).addGroupPhoto(widget.groupId, image);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto agregada al collage')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyPhotoError(error))),
      );
    }
  }

  Future<void> _deletePhoto(GroupPhotoModel photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar foto'),
          content: const Text('Esta foto se quitará del collage y también del almacenamiento.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _deletingPhotoIds.add(photo.id);
      _hiddenPhotoIds.add(photo.id);
    });

    try {
      await ref.read(groupsRepositoryProvider).deleteGroupPhoto(photo.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto eliminada del collage')),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _hiddenPhotoIds.remove(photo.id);
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar la foto: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deletingPhotoIds.remove(photo.id);
        });
      }
    }
  }

  Future<void> _copyWebLink() async {
    final links = await _inviteLinksFuture;
    await Clipboard.setData(ClipboardData(text: links.webLink));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link web copiado')),
    );
  }

  Future<void> _shareCover() async {
    if (!mounted) return;
    setState(() {
      _isPreparingShare = true;
    });

    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _coverKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final file = File('${Directory.systemTemp.path}/vibeloop_group_cover_${widget.groupId}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      final links = await _inviteLinksFuture;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: links.webLink,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPreparingShare = false;
        });
      }
    }
  }

  Widget _buildPhotoImage(GroupPhotoModel photo) {
    final repository = ref.read(groupsRepositoryProvider);
    final resolvedUrl = photo.imageUrl.trim().isNotEmpty
        ? photo.imageUrl.trim()
        : repository.publicGroupPhotoUrl(photo.storagePath).trim();
    final uri = Uri.tryParse(resolvedUrl);

    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return Image.network(
        resolvedUrl,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => _buildPhotoPlaceholder(),
      );
    }

    return _buildPhotoPlaceholder();
  }

  Widget _buildPhotoPlaceholder() {
    return const Center(
      child: Icon(
        Icons.broken_image_outlined,
        size: 34,
        color: Color(0xFF94A3B8),
      ),
    );
  }

  Widget _buildCoverTile({
    required BuildContext context,
    required GroupPhotoModel? photo,
    required bool showControls,
  }) {
    if (photo == null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: _addPhoto,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white.withValues(alpha: 0.72),
              border: Border.all(color: const Color(0xFF2EA8FF).withValues(alpha: 0.10)),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_a_photo_outlined,
                    color: const Color(0xFF2EA8FF).withValues(alpha: 0.82),
                    size: 30,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Agrega una foto',
                    style: TextStyle(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.70),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final deleting = _deletingPhotoIds.contains(photo.id);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _showPhotoPreview(context, photo),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildPhotoImage(photo),
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.10),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                top: 10,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.78),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      photo.uploaderEmoji,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ),
              ),
              if (showControls)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.88),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: deleting ? null : () => _deletePhoto(photo),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: deleting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                Icons.delete_outline_rounded,
                                size: 16,
                                color: Colors.redAccent.withValues(alpha: 0.90),
                              ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollage({
    required BuildContext context,
    required List<GroupPhotoModel> photos,
    required String? currentUserId,
    required bool canDeleteAnyPhoto,
  }) {
    if (photos.isEmpty) {
      return AspectRatio(
        aspectRatio: 1.06,
        child: _buildCoverTile(context: context, photo: null, showControls: false),
      );
    }

    if (photos.length == 1) {
      final photo = photos.first;
      final canDeletePhoto = currentUserId != null && (photo.uploadedBy == currentUserId || canDeleteAnyPhoto);
      return AspectRatio(
        aspectRatio: 0.84,
        child: _buildCoverTile(context: context, photo: photo, showControls: !_isPreparingShare && canDeletePhoto),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: photos.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: photos.length == 2 ? 1 : 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: photos.length == 2 ? 1.18 : 0.94,
      ),
      itemBuilder: (context, index) {
        final photo = photos[index];
        final canDeletePhoto = currentUserId != null && (photo.uploadedBy == currentUserId || canDeleteAnyPhoto);
        return _buildCoverTile(context: context, photo: photo, showControls: !_isPreparingShare && canDeletePhoto);
      },
    );
  }

  String _friendlyPhotoError(Object error) {
    final message = error.toString();
    if (message.contains('rate_limited_cooldown')) {
      return 'Espera un momento antes de subir otra foto.';
    }
    if (message.contains('rate_limited')) {
      return 'Has subido demasiadas fotos en poco tiempo.';
    }
    if (message.contains('Invalid photo payload') || message.contains('Invalid storage path')) {
      return 'No se pudo preparar la foto para subirla.';
    }
    if (message.contains('La foto debe pesar menos de 8 MB')) {
      return 'La foto debe pesar menos de 8 MB.';
    }
    return 'No se pudo agregar la foto: $message';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return VibeScaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Volver',
              onPressed: () => context.pop(),
              icon: VibeSvgIcon(VibeAssetIcons.arrowBack, size: 18, color: colorScheme.onSurface),
            ),
          ),
        ),
        leadingWidth: 56,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Fotos del grupo',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              'Collage compartido',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: IconButton(
              tooltip: 'Compartir portada',
              onPressed: _shareCover,
              icon: VibeSvgIcon(VibeAssetIcons.share, size: 18, color: colorScheme.primary),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: IconButton(
              tooltip: 'Agregar foto',
              onPressed: _addPhoto,
              icon: VibeSvgIcon(VibeAssetIcons.camera, size: 20, color: colorScheme.primary),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const GlassBottomNavigation(child: VibeLoopBannerAd()),
      body: StreamBuilder<List<GroupPhotoModel>>(
        stream: _photosStream,
        builder: (context, snapshot) {
          final photos = (snapshot.data ?? const <GroupPhotoModel>[])
              .where((photo) => !_hiddenPhotoIds.contains(photo.id))
              .toList();

          return FutureBuilder<GroupModel>(
            future: _groupFuture,
            builder: (context, groupSnapshot) {
              final group = groupSnapshot.data;
              final currentUserId = Supabase.instance.client.auth.currentUser?.id;
              final canDeleteAnyPhoto = group != null && currentUserId != null && group.createdBy == currentUserId;

              return FutureBuilder<InviteLinks>(
                future: _inviteLinksFuture,
                builder: (context, linksSnapshot) {
                  final webLink = linksSnapshot.data?.webLink;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fotos del grupo',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Toca + para sumar nuevas fotos',
                              style: TextStyle(
                                color: Colors.black.withValues(alpha: 0.50),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        RepaintBoundary(
                          key: _coverKey,
                          child: _buildCollage(
                            context: context,
                            photos: photos,
                            currentUserId: currentUserId,
                            canDeleteAnyPhoto: canDeleteAnyPhoto,
                          ),
                        ),
                        if (!_isPreparingShare) ...[
                          const SizedBox(height: 14),
                          GlassCard(
                            borderRadius: 22,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                const VibeSvgIcon(VibeAssetIcons.share, size: 18, color: Color(0xFF2EA8FF)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    webLink ?? 'Link web',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: webLink == null ? null : _copyWebLink,
                                  child: const Text('Copiar'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showPhotoPreview(BuildContext context, GroupPhotoModel photo) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Container(
              color: const Color(0xFFF6F9FC),
              child: AspectRatio(
                aspectRatio: 0.9,
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 3,
                  child: Center(
                    child: _buildPhotoImage(photo),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

}
