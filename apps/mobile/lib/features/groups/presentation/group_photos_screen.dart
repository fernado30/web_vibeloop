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
import '../../../core/utils/error_helper.dart';
import '../data/groups_repository.dart';
import '../domain/group_model.dart';
import '../domain/group_photo_model.dart';
import '../../settings/presentation/report_bottom_sheet.dart';

class GroupPhotosScreen extends ConsumerStatefulWidget {
  const GroupPhotosScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupPhotosScreen> createState() => _GroupPhotosScreenState();
}

class _GroupPhotosScreenState extends ConsumerState<GroupPhotosScreen> {
  late Stream<List<GroupPhotoModel>> _photosStream;
  late final Future<InviteLinks> _inviteLinksFuture;
  late final Future<GroupModel> _groupFuture;
  final GlobalKey _coverKey = GlobalKey();
  final Set<String> _deletingPhotoIds = <String>{};
  final Set<String> _hiddenPhotoIds = <String>{};
  final List<GroupPhotoModel> _optimisticPhotos = <GroupPhotoModel>[];
  final Map<String, String> _localPreviewPaths = <String, String>{};
  bool _isPreparingShare = false;

  @override
  void initState() {
    super.initState();
    _photosStream = _buildPhotosStream();
    _inviteLinksFuture = ref.read(groupsRepositoryProvider).generateInviteLinks(widget.groupId);
    _groupFuture = ref.read(groupsRepositoryProvider).getGroupById(widget.groupId);
  }

  Stream<List<GroupPhotoModel>> _buildPhotosStream() {
    final repository = ref.read(groupsRepositoryProvider);
    return Stream.fromFuture(repository.fetchGroupPhotos(widget.groupId)).asyncExpand((initialPhotos) async* {
      yield initialPhotos;
      yield* repository.watchGroupPhotos(widget.groupId);
    });
  }

  void _reloadPhotos() {
    if (!mounted) return;
    setState(() {
      _photosStream = _buildPhotosStream();
    });
  }

  List<GroupPhotoModel> _mergePhotos(List<GroupPhotoModel> remotePhotos) {
    final remoteIds = remotePhotos.map((photo) => photo.id).toSet();
    final byId = <String, GroupPhotoModel>{
      for (final photo in remotePhotos) photo.id: photo,
    };

    for (final photo in _optimisticPhotos.where((photo) => !remoteIds.contains(photo.id) && !_hiddenPhotoIds.contains(photo.id))) {
      byId.putIfAbsent(photo.id, () => photo);
    }

    final merged = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return merged;
  }

  void _registerOptimisticPhoto(
    GroupPhotoModel photo, {
    String? localPreviewPath,
  }) {
    if (_optimisticPhotos.any((item) => item.id == photo.id)) {
      return;
    }

    setState(() {
      _optimisticPhotos.insert(0, photo);
      if (localPreviewPath != null && localPreviewPath.trim().isNotEmpty) {
        _localPreviewPaths[photo.id] = localPreviewPath.trim();
      }
    });
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
      final photo = await ref.read(groupsRepositoryProvider).addGroupPhoto(widget.groupId, image);
      if (!mounted) return;
      _registerOptimisticPhoto(photo, localPreviewPath: image.path);
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
      if (mounted) {
        setState(() {
          _optimisticPhotos.removeWhere((item) => item.id == photo.id);
          _localPreviewPaths.remove(photo.id);
        });
      }
      _reloadPhotos();
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
    final localFile = _resolveLocalPreviewFile(_localPreviewPaths[photo.id]);
    if (localFile != null) {
      return ColoredBox(
        color: Colors.white,
        child: Image.file(
          localFile,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
        ),
      );
    }

    return ColoredBox(
      color: Colors.white,
      child: FutureBuilder<Uint8List?>( 
        future: repository.resolveGroupPhotoBytes(photo.storagePath),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes != null && bytes.isNotEmpty) {
            return ColoredBox(
              color: Colors.white,
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                alignment: Alignment.center,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
              ),
            );
          }

          return FutureBuilder<String?>(
            future: repository.resolveGroupPhotoSignedUrl(photo.storagePath),
            builder: (context, urlSnapshot) {
              final resolvedUrl = _resolveRemotePhotoUrl(photo.imageUrl, urlSnapshot.data);
              return _buildNetworkPhoto(resolvedUrl);
            },
          );
        },
      ),
    );
  }

  File? _resolveLocalPreviewFile(String? path) {
    final trimmed = path?.trim() ?? '';
    if (trimmed.isEmpty) return null;

    final directFile = File(trimmed);
    if (directFile.existsSync()) {
      return directFile;
    }

    if (trimmed.startsWith('file://')) {
      try {
        final uri = Uri.parse(trimmed);
        final fileFromUri = File(uri.toFilePath());
        if (fileFromUri.existsSync()) {
          return fileFromUri;
        }
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  String? _resolveRemotePhotoUrl(String storedUrl, String? signedUrl) {
    final trimmedStoredUrl = storedUrl.trim();
    if (_isHttpUrl(trimmedStoredUrl)) {
      return trimmedStoredUrl;
    }

    final trimmedSignedUrl = signedUrl?.trim() ?? '';
    if (_isHttpUrl(trimmedSignedUrl)) {
      return trimmedSignedUrl;
    }

    return null;
  }

  bool _isHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  Widget _buildNetworkPhoto(String? resolvedUrl) {
    final url = resolvedUrl?.trim() ?? '';
    if (!_isHttpUrl(url)) {
      return _buildPhotoPlaceholder();
    }

    return Image.network(
      url,
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

  Widget _buildPhotoPlaceholder() {
    return Container(
      color: Colors.white,
      child: const Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: 34,
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }

  Widget _buildEmptyGalleryState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgStart = isDark
        ? const Color(0xFF1A2540).withValues(alpha: 0.90)
        : const Color(0xFF2EA8FF).withValues(alpha: 0.10);
    final bgEnd = isDark
        ? const Color(0xFF111827).withValues(alpha: 0.95)
        : Colors.white.withValues(alpha: 0.90);
    final titleColor = isDark ? const Color(0xFFF0F4FF) : const Color(0xFF0F172A);
    final subtitleColor = isDark
        ? const Color(0xFF8A9BBD)
        : Colors.black.withValues(alpha: 0.55);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: _addPhoto,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: [bgStart, bgEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: const Color(0xFF2EA8FF).withValues(alpha: isDark ? 0.22 : 0.14),
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2EA8FF).withValues(alpha: isDark ? 0.18 : 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_a_photo_outlined,
                      size: 36,
                      color: Color(0xFF2EA8FF),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aún no hay fotos',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Toca para agregar la primera foto del grupo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _addPhoto,
                    icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                    label: const Text('Agregar foto'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2EA8FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGalleryActionBar(BuildContext context, {required bool showAddButton}) {
    if (!showAddButton) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barBg = isDark
        ? const Color(0xFF0F172A).withValues(alpha: 0.86)
        : Colors.white.withValues(alpha: 0.92);
    final barBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE8EAF3);
    final labelColor = isDark ? const Color(0xFFF1F5FF) : const Color(0xFF1F2937);
    final arrowColor = isDark
        ? Colors.white.withValues(alpha: 0.62)
        : const Color(0xFF374151);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: _addPhoto,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: barBg,
            border: Border.all(color: barBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF4F46E5),
                      Color(0xFF8B5CF6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.add_a_photo_outlined,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Agregar foto',
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: arrowColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverTile({
    required BuildContext context,
    required GroupPhotoModel photo,
    required bool showControls,
    required bool showEmoji,
  }) {
    final deleting = _deletingPhotoIds.contains(photo.id);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => _showPhotoPreview(context, photo),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF2563EB),
                Color(0xFF8B5CF6),
                Color(0xFFD946EF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.26 : 0.22),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.10),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(2),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
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
                          Colors.black.withValues(alpha: isDark ? 0.06 : 0.03),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                if (showControls)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Builder(
                      builder: (context) {
                        final isDarkTile = Theme.of(context).brightness == Brightness.dark;
                        return Material(
                          color: isDarkTile ? Colors.white.withValues(alpha: 0.96) : Colors.white.withValues(alpha: 0.98),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: deleting ? null : () => _deletePhoto(photo),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: deleting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: isDarkTile ? const Color(0xFF111827) : const Color(0xFF111827),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                if (showEmoji)
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? const [
                                  Color(0xFFFFF4D8),
                                  Color(0xFFFFE2AE),
                                ]
                              : const [
                                  Color(0xFFFFF8EA),
                                  Color(0xFFFFEECF),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.88), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          photo.uploaderEmoji,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22, height: 1),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
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
    bool showDeleteControls = true,
  }) {
    if (photos.isEmpty) {
      return AspectRatio(
        aspectRatio: 1.05,
        child: _buildEmptyGalleryState(context),
      );
    }

    final leadPhoto = photos.first;
    final leadCanDelete = currentUserId != null && (leadPhoto.uploadedBy == currentUserId || canDeleteAnyPhoto);
    final remainingPhotos = photos.skip(1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 0.82,
          child: _buildCoverTile(
            context: context,
            photo: leadPhoto,
            showControls: showDeleteControls && leadCanDelete,
            showEmoji: true,
          ),
        ),
        if (remainingPhotos.isNotEmpty) ...[
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: remainingPhotos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.96,
            ),
            itemBuilder: (context, index) {
              final photo = remainingPhotos[index];
              final canDeletePhoto = currentUserId != null && (photo.uploadedBy == currentUserId || canDeleteAnyPhoto);
              return _buildCoverTile(
                context: context,
                photo: photo,
                showControls: showDeleteControls && canDeletePhoto,
                showEmoji: true,
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildShareCoverCollage({
    required BuildContext context,
    required List<GroupPhotoModel> photos,
  }) {
    Widget wrapWhite(Widget child) => ColoredBox(color: Colors.white, child: child);

    if (photos.isEmpty) {
      return wrapWhite(
        AspectRatio(
          aspectRatio: 1.0,
          child: _buildEmptyGalleryState(context),
        ),
      );
    }

    final visiblePhotos = photos.toList();

    if (visiblePhotos.length == 1) {
      return wrapWhite(
        AspectRatio(
          aspectRatio: 1.0,
          child: _buildCoverTile(
            context: context,
            photo: visiblePhotos.first,
            showControls: false,
            showEmoji: true,
          ),
        ),
      );
    }

    if (visiblePhotos.length == 2) {
      return wrapWhite(
        AspectRatio(
          aspectRatio: 0.52,
          child: Column(
            children: [
              Expanded(
                child: _buildCoverTile(
                  context: context,
                  photo: visiblePhotos[0],
                  showControls: false,
                  showEmoji: true,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _buildCoverTile(
                  context: context,
                  photo: visiblePhotos[1],
                  showControls: false,
                  showEmoji: true,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (visiblePhotos.length == 3) {
      return wrapWhite(
        AspectRatio(
          aspectRatio: 1.0,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: _buildCoverTile(
                        context: context,
                        photo: visiblePhotos[0],
                        showControls: false,
                        showEmoji: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _buildCoverTile(
                        context: context,
                        photo: visiblePhotos[1],
                        showControls: false,
                        showEmoji: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCoverTile(
                  context: context,
                  photo: visiblePhotos[2],
                  showControls: false,
                  showEmoji: true,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return wrapWhite(
      LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = width >= 720
              ? 4
              : width >= 520
                  ? 3
                  : 2;

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visiblePhotos.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final photo = visiblePhotos[index];
              return _buildCoverTile(
                context: context,
                photo: photo,
                showControls: false,
                showEmoji: true,
              );
            },
          );
        },
      ),
    );
  }

  String _friendlyPhotoError(Object error) {
    if (isNetworkError(error)) {
      return getFriendlyNetworkError(actionContext: 'subir la foto');
    }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return VibeScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 92,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        leading: Builder(
          builder: (context) {
            final isDarkBtn = Theme.of(context).brightness == Brightness.dark;
            return Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: Ink(
                  decoration: BoxDecoration(
                    color: isDarkBtn
                        ? const Color(0xFF111827).withValues(alpha: 0.88)
                        : Colors.white.withValues(alpha: 0.92),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDarkBtn
                          ? Colors.white.withValues(alpha: 0.06)
                          : const Color(0xFFE6E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDarkBtn ? 0.26 : 0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: IconButton(
                    tooltip: 'Volver',
                    onPressed: () => context.pop(),
                    icon: VibeSvgIcon(
                      VibeAssetIcons.arrowBack,
                      size: 20,
                      color: isDarkBtn ? const Color(0xFFF1F5F9) : const Color(0xFF111827),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        leadingWidth: 68,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Fotos del grupo',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                        letterSpacing: -0.3,
                      ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF8B5CF6)),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              'Collage compartido',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? const Color(0xFFB4B9C6) : const Color(0xFF7C3AED),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Material(
              color: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF8B5CF6),
                      Color(0xFFA855F7),
                      Color(0xFFF43F5E),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.26),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: IconButton(
                  tooltip: 'Compartir portada',
                  onPressed: _shareCover,
                  icon: const Icon(Icons.ios_share_rounded, size: 20, color: Colors.white),
                ),
              ),
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
          final visiblePhotos = _mergePhotos(photos);

          return FutureBuilder<GroupModel>(
            future: _groupFuture,
            builder: (context, groupSnapshot) {
              final group = groupSnapshot.data;
              final currentUserId = Supabase.instance.client.auth.currentUser?.id;
              final canDeleteAnyPhoto = group != null && currentUserId != null && group.createdBy == currentUserId;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildGalleryActionBar(context, showAddButton: true),
                    if (visiblePhotos.isNotEmpty) const SizedBox(height: 12),
                    RepaintBoundary(
                      key: _coverKey,
                      child: _isPreparingShare
                          ? _buildShareCoverCollage(
                              context: context,
                              photos: visiblePhotos,
                            )
                          : _buildCollage(
                              context: context,
                              photos: visiblePhotos,
                              currentUserId: currentUserId,
                              canDeleteAnyPhoto: canDeleteAnyPhoto,
                            ),
                    ),
                  ],
                ),
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
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Container(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: 0.9,
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 3,
                      child: Center(
                        child: _buildPhotoImage(photo),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              photo.uploaderEmoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Foto de grupo',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black87,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            final reported = await ReportBottomSheet.show(
                              context,
                              targetType: 'group_photo',
                              targetId: photo.id,
                              title: 'Denunciar foto',
                            );
                            if (reported == true && mounted) {
                              setState(() {
                                _hiddenPhotoIds.add(photo.id);
                              });
                            }
                          },
                          icon: const Icon(Icons.flag_outlined, size: 18, color: Color(0xFFF43F5E)),
                          label: const Text(
                            'Denunciar foto',
                            style: TextStyle(color: Color(0xFFF43F5E), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
