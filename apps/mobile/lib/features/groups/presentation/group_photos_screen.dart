import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:ui' as ui;

import '../../../core/ads/vibe_loop_banner_ad.dart';
import '../data/groups_repository.dart';
import '../domain/group_photo_model.dart';
import '../domain/group_model.dart';

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
        SnackBar(content: Text('No se pudo agregar la foto: $error')),
      );
    }
  }

  Future<void> _deletePhoto(GroupPhotoModel photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar foto'),
          content: const Text('Esta foto se quitara del collage y tambien del almacenamiento.'),
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

  int _shareCrossAxisCount(int photoCount) {
    return photoCount <= 2 ? 1 : 2;
  }

  double _shareChildAspectRatio(int photoCount) {
    return photoCount <= 2 ? 1.45 : 1.0;
  }

  Widget _buildShareCollage({
    required BuildContext context,
    required List<GroupPhotoModel> photos,
    required String? currentUserId,
    required bool canDeleteAnyPhoto,
  }) {
    final sharePhotos = photos.isEmpty ? <GroupPhotoModel?>[null] : photos.cast<GroupPhotoModel?>();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: sharePhotos.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _shareCrossAxisCount(sharePhotos.length),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: _shareChildAspectRatio(sharePhotos.length),
        ),
        itemBuilder: (context, index) {
          final photo = sharePhotos[index];
          final canDeletePhoto = photo != null &&
              currentUserId != null &&
              (photo.uploadedBy == currentUserId || canDeleteAnyPhoto);
          return _buildPhotoTile(
            context,
            photo,
            showControls: !_isPreparingShare && canDeletePhoto,
          );
        },
      ),
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

      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/vibeloop_group_cover_${widget.groupId}.png');
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

  Widget _buildPhotoTile(
    BuildContext context,
    GroupPhotoModel? photo, {
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: const Color(0xFFF6F9FC),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _buildPhotoImage(photo),
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.14),
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
    );
  }

  Widget _buildPhotoImage(GroupPhotoModel photo) {
    final repository = ref.read(groupsRepositoryProvider);
    final resolvedUrl = repository.publicGroupPhotoUrl(photo.storagePath).trim().isNotEmpty
        ? repository.publicGroupPhotoUrl(photo.storagePath)
        : photo.imageUrl.trim();
    final uri = Uri.tryParse(resolvedUrl);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return Image.network(
        resolvedUrl,
        fit: BoxFit.contain,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fotos del grupo'),
        actions: [
          TextButton.icon(
            onPressed: _shareCover,
            icon: const Icon(Icons.ios_share_rounded, size: 18),
            label: const Text('Compartir portada'),
          ),
          IconButton(
            tooltip: 'Agregar foto',
            onPressed: _addPhoto,
            icon: const Icon(Icons.add_a_photo_outlined),
          ),
        ],
      ),
      bottomNavigationBar: const SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: VibeLoopBannerAd(),
        ),
      ),
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
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF2EA8FF), Color(0xFF8AD8FF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
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
                                    'Toca + para sumar nuevas fotos al collage',
                                    style: TextStyle(
                                      color: Colors.black.withValues(alpha: 0.50),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!_isPreparingShare)
                              IconButton(
                                tooltip: 'Agregar foto',
                                onPressed: _addPhoto,
                                icon: const Icon(Icons.add_photo_alternate_outlined),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        RepaintBoundary(
                          key: _coverKey,
                          child: _buildShareCollage(
                            context: context,
                            photos: photos,
                            currentUserId: currentUserId,
                            canDeleteAnyPhoto: canDeleteAnyPhoto,
                          ),
                        ),
                        if (!_isPreparingShare) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.58),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: const Color(0xFF2EA8FF).withValues(alpha: 0.10)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.language_rounded, size: 18, color: Color(0xFF2EA8FF)),
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
}
