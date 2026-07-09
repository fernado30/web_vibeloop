import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/invite_link_config.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/utils/profile_emojis.dart';
import '../domain/group_photo_model.dart';
import '../domain/group_model.dart';

final groupsRepositoryProvider = Provider<GroupsRepository>((ref) {
  return GroupsRepository(Supabase.instance.client);
});

final groupsControllerProvider = StateNotifierProvider<GroupsController, AsyncValue<List<GroupModel>>>((ref) {
  return GroupsController(ref.read(groupsRepositoryProvider));
});

String _safeSlug(String value) {
  final slug = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'invitado' : slug;
}

class GroupsRepository {
  GroupsRepository(this._client);

  final SupabaseClient _client;
  final Map<String, _GroupPhotoUrlCacheEntry> _groupPhotoUrlCache = {};
  final Map<String, Future<Uint8List?>> _groupPhotoBytesCache = {};

  SupabaseClient get _supabase => _client;

  Future<T> _withInviteCodeHeader<T>(
    String inviteCode,
    Future<T> Function(SupabaseClient client) action,
  ) async {
    final config = await SupabaseConfig.load();
    final currentSession = _supabase.auth.currentSession;
    final headers = <String, String>{
      'x-invite-code': inviteCode,
      if (currentSession != null) 'Authorization': 'Bearer ${currentSession.accessToken}',
    };
    final inviteScopedClient = SupabaseClient(
      config.url,
      config.anonKey,
      headers: headers,
    );
    try {
      return await action(inviteScopedClient);
    } finally {
      await inviteScopedClient.dispose();
    }
  }

  Future<T> _runWithSchemaCheck<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (exception) {
      final missingTable = RegExp(r"'public\.([a-z_]+)'", caseSensitive: false).firstMatch(exception.message);
      if (exception.code == 'PGRST205' && missingTable != null) {
        final tableName = missingTable.group(1)!;
        throw StateError(
          'La tabla "$tableName" no existe en el proyecto Supabase actual.\n'
          'Revisa que estes usando el proyecto correcto y aplica el SQL de supabase/schema.sql.',
        );
      }
      rethrow;
    }
  }

  Future<List<GroupModel>> fetchMyGroups() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return const [];
    }

    final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 5)).toIso8601String();
    final rows = await _loadMyGroupsRows(
      userId: user.id,
      activeSince: cutoff,
    );

    final groups = rows.map((row) {
      return GroupModel.fromJson(_normalizeGroupJson(Map<String, dynamic>.from(row as Map)));
    }).toList();

    return Future.wait(groups.map((group) async {
      final memberCount = await _countMembers(group.id);
      return group.copyWith(memberCount: memberCount);
    }));
  }

  Future<List<dynamic>> _loadMyGroupsRows({
    required String userId,
    required String activeSince,
  }) async {
    try {
      return await _runWithSchemaCheck(
        () => _supabase
            .from('groups')
            .select('id, name, description, image_url, created_by, invite_code, created_at, group_members!inner(user_id)')
            .eq('group_members.user_id', userId)
            .gte('last_activity_at', activeSince)
            .order('created_at', ascending: false),
      );
    } on PostgrestException catch (exception) {
      if (_looksLikeMissingLastActivityColumn(exception)) {
        return await _runWithSchemaCheck(
          () => _supabase
              .from('groups')
              .select('id, name, description, image_url, created_by, invite_code, created_at, group_members!inner(user_id)')
              .eq('group_members.user_id', userId)
              .order('created_at', ascending: false),
        );
      }
      rethrow;
    }
  }

  Future<GroupModel> createGroup({
    required String name,
    required String description,
    required String imageUrl,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw AuthException('Debes iniciar sesion para crear grupos.');
    }

    await _ensureUserProfile(user);

    final inserted = await _runWithSchemaCheck(
      () => _supabase.from('groups').insert({
        'name': name,
        'description': description,
        'image_url': imageUrl,
        'created_by': user.id,
      }).select('id, name, description, image_url, created_by, invite_code, created_at').single(),
    );

    await _runWithSchemaCheck(() => _supabase.from('group_members').insert({
          'group_id': inserted['id'],
          'user_id': user.id,
          'role': 'owner',
        }));

    final groupJson = Map<String, dynamic>.from(inserted);
    groupJson['member_count'] = 1;
    return GroupModel.fromJson(_normalizeGroupJson(groupJson));
  }

  Future<GroupModel> getGroupById(String id) async {
    final row = await _runWithSchemaCheck(
      () => _supabase
          .from('groups')
          .select('id, name, description, image_url, created_by, invite_code, created_at, group_members(user_id)')
          .eq('id', id)
          .single(),
    );

    final json = _normalizeGroupJson(Map<String, dynamic>.from(row));
    json['member_count'] = await _countMembers(id);
    return GroupModel.fromJson(json);
  }

  Future<List<GroupPhotoModel>> fetchGroupPhotos(String groupId) async {
    final rows = await _runWithSchemaCheck(
      () => _supabase
          .from('group_photos')
          .select('id, group_id, uploaded_by, uploader_emoji, image_url, storage_path, created_at')
          .eq('group_id', groupId)
          .order('created_at', ascending: false),
    );

    final photos = (rows as List<dynamic>).map((row) {
      return GroupPhotoModel.fromJson(Map<String, dynamic>.from(row as Map));
    }).toList();

    return _hydrateGroupPhotoUrls(await _attachUploaderEmojis(photos));
  }

  Stream<List<GroupPhotoModel>> watchGroupPhotos(String groupId) {
    final controller = StreamController<List<GroupPhotoModel>>.broadcast();
    final channel = _supabase.channel('group-photos-$groupId');
    Timer? refreshTimer;
    var cache = <GroupPhotoModel>[];
    var loaded = false;

    Future<void> emit() async {
      if (controller.isClosed) return;
      await _refreshCachedGroupPhotoUrls();
      cache = await fetchGroupPhotos(groupId);
      loaded = true;
      controller.add(cache);
    }

    Future<void> refreshSingle(String photoId) async {
      if (!loaded || controller.isClosed) {
        await emit();
        return;
      }

      final row = await _supabase
          .from('group_photos')
          .select('id, group_id, uploaded_by, uploader_emoji, image_url, storage_path, created_at')
          .eq('id', photoId)
          .maybeSingle();

      if (row == null) {
        await emit();
        return;
      }

      final photo = GroupPhotoModel.fromJson(Map<String, dynamic>.from(row as Map));
      final enrichedPhotos = await _hydrateGroupPhotoUrls(await _attachUploaderEmojis([photo]));
      final enrichedPhoto = enrichedPhotos.first;
      final existingIndex = cache.indexWhere((item) => item.id == enrichedPhoto.id);
      if (existingIndex == -1) {
        cache = [enrichedPhoto, ...cache];
      } else {
        cache = [
          ...cache.take(existingIndex),
          enrichedPhoto,
          ...cache.skip(existingIndex + 1),
        ];
      }

      if (!controller.isClosed) {
        controller.add(cache);
      }
    }

    Future<void> refreshAllIfUploaderChanged(String? userId) async {
      if (userId == null || userId.isEmpty) {
        return;
      }

      final shouldRefresh = cache.any((photo) => photo.uploadedBy == userId);
      if (!shouldRefresh) {
        return;
      }

      await emit();
    }

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'group_photos',
      filter: PostgresChangeFilter(column: 'group_id', value: groupId, type: PostgresChangeFilterType.eq),
      callback: (payload) {
        final photoId = payload.newRecord['id']?.toString();
        if (photoId == null || photoId.isEmpty) {
          emit();
          return;
        }
        refreshSingle(photoId);
      },
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'group_photos',
      filter: PostgresChangeFilter(column: 'group_id', value: groupId, type: PostgresChangeFilterType.eq),
      callback: (payload) {
        final photoId = payload.newRecord['id']?.toString();
        if (photoId == null || photoId.isEmpty) {
          emit();
          return;
        }
        refreshSingle(photoId);
      },
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'group_photos',
      filter: PostgresChangeFilter(column: 'group_id', value: groupId, type: PostgresChangeFilterType.eq),
      callback: (payload) {
        final deletedId = payload.oldRecord['id']?.toString();
        if (deletedId == null || deletedId.isEmpty) {
          emit();
          return;
        }

        cache = cache.where((photo) => photo.id != deletedId).toList();
        emit();
      },
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'users',
      callback: (payload) {
        final userId = payload.newRecord['id']?.toString();
        refreshAllIfUploaderChanged(userId);
      },
    );

    channel.subscribe();
    emit();

    refreshTimer = Timer.periodic(const Duration(minutes: 45), (_) {
      if (!controller.isClosed) {
        unawaited(emit());
      }
    });

    controller.onCancel = () async {
      refreshTimer?.cancel();
      channel.unsubscribe();
      await controller.close();
    };

    return controller.stream;
  }

  Future<GroupPhotoModel> addGroupPhoto(String groupId, XFile image) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw AuthException('Debes iniciar sesion para subir fotos.');
    }

    await _ensureUserProfile(user);
    final profile = await _runWithSchemaCheck(
      () => _supabase.from('users').select('emoji').eq('id', user.id).maybeSingle(),
    );
    final uploaderEmoji = profile?['emoji']?.toString() ?? user.userMetadata?['emoji']?.toString() ?? emojiForSeed(user.id);

    final extension = _imageExtension(image.path);
    final storagePath = 'groups/$groupId/${user.id}/${DateTime.now().millisecondsSinceEpoch}.$extension';
    final file = File(image.path);
    final fileSize = await file.length();
    if (fileSize > 8 * 1024 * 1024) {
      throw StateError('La foto debe pesar menos de 8 MB.');
    }

    try {
      await _supabase.storage.from('group-photos').upload(
            storagePath,
            file,
            fileOptions: FileOptions(contentType: _imageContentType(extension)),
          );

      final displayUrl = await _resolveGroupPhotoDisplayUrl(
        storagePath: storagePath,
        fallbackUrl: _supabase.storage.from('group-photos').getPublicUrl(storagePath),
      );
      final row = await _runWithSchemaCheck(
        () => _supabase
          .from('group_photos')
          .insert({
              'group_id': groupId,
              'uploaded_by': user.id,
              'uploader_emoji': uploaderEmoji,
              'image_url': displayUrl,
              'storage_path': storagePath,
            })
            .select('id, group_id, uploaded_by, uploader_emoji, image_url, storage_path, created_at')
            .single(),
      );

      final photo = GroupPhotoModel.fromJson(Map<String, dynamic>.from(row));
      final hydrated = await _hydrateGroupPhotoUrls(await _attachUploaderEmojis([photo]));
      return hydrated.first;
    } catch (_) {
      await _supabase.storage.from('group-photos').remove([storagePath]);
      rethrow;
    }
  }

  Future<void> deleteGroupPhoto(String photoId) async {
    final row = await _runWithSchemaCheck(
      () => _supabase
          .from('group_photos')
          .select('id, storage_path')
          .eq('id', photoId)
          .maybeSingle(),
    );

    if (row == null) {
      throw StateError('La foto ya no existe.');
    }

    final storagePath = row['storage_path']?.toString();
    await _runWithSchemaCheck(
      () => _supabase.from('group_photos').delete().eq('id', photoId),
    );

    if (storagePath != null && storagePath.isNotEmpty) {
      unawaited(() async {
        try {
          await _supabase.storage.from('group-photos').remove([storagePath]);
        } catch (_) {
          // The photo is already gone from the collage; storage cleanup can be retried later.
        }
      }());
    }
  }

  Future<InviteLinks> generateInviteLinks(String groupId) async {
    final row = await _runWithSchemaCheck(() => _supabase.from('groups').select('invite_code').eq('id', groupId).single());
    final inviteCode = row['invite_code'] as String;
    final config = await InviteLinkConfig.load();

    final user = _supabase.auth.currentUser;
    final profile = user == null
        ? null
        : await _runWithSchemaCheck(
            () => _supabase.from('users').select('display_name, emoji').eq('id', user.id).maybeSingle(),
          );

    final displayName = (profile?['display_name']?.toString() ??
            user?.userMetadata?['display_name']?.toString() ??
            user?.email?.split('@').first ??
            'invitado')
        .trim();
    final inviteNumber = 1000 + Random().nextInt(9000);
    final token = '${_safeSlug(displayName)}-$inviteNumber-$inviteCode';
    final normalizedWebUrl = config.webUrl.replaceAll(RegExp(r'/+$'), '');
    final appLink = 'vibeloop://invite/$token';
    final webLink = '$normalizedWebUrl/buzon/$token';

    return InviteLinks(appLink: appLink, webLink: webLink);
  }

  Future<GroupModel> getGroupByInviteCode(String inviteCode) async {
    final row = await _runWithSchemaCheck(
      () => _withInviteCodeHeader(
        inviteCode,
        (client) => client
            .from('groups')
            .select('id, name, description, image_url, created_by, invite_code, created_at')
            .eq('invite_code', inviteCode)
            .limit(1)
            .maybeSingle(),
      ),
    );

    if (row == null) {
      throw StateError('La invitación no existe o ya no es válida.');
    }

    final json = _normalizeGroupJson(Map<String, dynamic>.from(row));
    json['member_count'] = await _countMembers(json['id'] as String);
    return GroupModel.fromJson(json);
  }

  Future<bool> isInvitePausedForCode(String inviteCode) async {
    final row = await _runWithSchemaCheck(
      () => _withInviteCodeHeader(
        inviteCode,
        (client) => client
            .from('groups')
            .select('invite_paused')
            .eq('invite_code', inviteCode)
            .limit(1)
            .maybeSingle(),
      ),
    );

    return row?['invite_paused'] == true;
  }

  Future<List<GroupInviteSetting>> fetchOwnedGroupInviteSettings() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return const [];
    }

    final rows = await _runWithSchemaCheck(
      () => _supabase
          .from('groups')
          .select('id, name, invite_code, invite_paused, created_at')
          .eq('created_by', user.id)
          .order('created_at', ascending: false),
    );

    return (rows as List<dynamic>).map((row) {
      final json = Map<String, dynamic>.from(row as Map);
      return GroupInviteSetting(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        inviteCode: json['invite_code']?.toString() ?? '',
        invitePaused: json['invite_paused'] == true,
        createdAt: DateTime.parse(json['created_at']?.toString() ?? DateTime.now().toIso8601String()),
      );
    }).where((group) => group.id.isNotEmpty).toList();
  }

  Future<void> setGroupInvitePaused({
    required String groupId,
    required bool paused,
  }) async {
    await _runWithSchemaCheck(
      () => _supabase.from('groups').update({'invite_paused': paused}).eq('id', groupId),
    );
  }

  Future<void> deleteGroup(String groupId) async {
    try {
      final response = await _supabase.functions.invoke(
        'delete-group',
        body: {'groupId': groupId},
      );

      if (response.status < 200 || response.status >= 300) {
        final payload = response.data;
        final message = payload is Map<String, dynamic> && payload['error'] != null
            ? payload['error'].toString()
            : 'No se pudo eliminar el grupo.';
        throw StateError(message);
      }
    } on FunctionException catch (error) {
      if (error.status != 404) {
        rethrow;
      }

      await _deleteGroupLocally(groupId);
    }
  }

  Future<void> joinGroup(String groupId, {String? inviteCode}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw AuthException('No hay una sesion activa.');
    }

    await _ensureUserProfile(user);
    await _runWithSchemaCheck(
      () => _withInviteCodeHeader(
        inviteCode ?? '',
        (client) => client.from('group_members').upsert(
            {
              'group_id': groupId,
              'user_id': user.id,
              'role': 'member',
            },
            onConflict: 'group_id,user_id',
            ignoreDuplicates: true,
          ),
      ),
    );
  }

  Future<int> _countMembers(String groupId) async {
    final rows = await _runWithSchemaCheck(() => _supabase.from('group_members').select('id').eq('group_id', groupId));
    return (rows as List<dynamic>).length;
  }

  Future<void> _deleteGroupLocally(String groupId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw AuthException('No hay una sesion activa.');
    }

    final group = await _runWithSchemaCheck(
      () => _supabase.from('groups').select('id, created_by').eq('id', groupId).maybeSingle(),
    );

    if (group == null) {
      throw StateError('El grupo ya no existe.');
    }

    if (group['created_by']?.toString() != user.id) {
      throw StateError('Solo el creador puede eliminar este grupo.');
    }

    final photoRows = await _runWithSchemaCheck(
      () => _supabase.from('group_photos').select('storage_path').eq('group_id', groupId),
    );

    final storagePaths = (photoRows as List<dynamic>)
        .map((row) => (row as Map)['storage_path']?.toString().trim() ?? '')
        .where((path) => path.isNotEmpty)
        .toSet()
        .toList();

    if (storagePaths.isNotEmpty) {
      await _supabase.storage.from('group-photos').remove(storagePaths);
    }

    await _runWithSchemaCheck(
      () => _supabase.from('groups').delete().eq('id', groupId),
    );
  }

  Future<String> _resolveGroupPhotoDisplayUrl({
    required String storagePath,
    required String fallbackUrl,
  }) async {
    final trimmedPath = storagePath.trim();
    final trimmedFallbackUrl = fallbackUrl.trim();
    if (trimmedPath.isEmpty) {
      return trimmedFallbackUrl;
    }

    final cached = _groupPhotoUrlCache[trimmedPath];
    final now = DateTime.now();
    if (cached != null && cached.expiresAt.isAfter(now.add(const Duration(minutes: 10)))) {
      return cached.url;
    }

    final signedUrl = await resolveGroupPhotoSignedUrl(trimmedPath);
    if (signedUrl != null && signedUrl.isNotEmpty) {
      _groupPhotoUrlCache[trimmedPath] = _GroupPhotoUrlCacheEntry(
        url: signedUrl,
        expiresAt: now.add(_groupPhotoSignedUrlTtl),
      );
      return signedUrl;
    }

    return trimmedFallbackUrl.isNotEmpty ? trimmedFallbackUrl : publicGroupPhotoUrl(trimmedPath);
  }

  Future<void> _refreshCachedGroupPhotoUrls() async {
    if (_groupPhotoUrlCache.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final expiredPaths = _groupPhotoUrlCache.entries
        .where((entry) => entry.value.expiresAt.isBefore(now.add(const Duration(minutes: 10))))
        .map((entry) => entry.key)
        .toList();

    if (expiredPaths.isEmpty) {
      return;
    }

    for (final storagePath in expiredPaths) {
      final signedUrl = await resolveGroupPhotoSignedUrl(storagePath);
      if (signedUrl != null && signedUrl.isNotEmpty) {
        _groupPhotoUrlCache[storagePath] = _GroupPhotoUrlCacheEntry(
          url: signedUrl,
          expiresAt: now.add(_groupPhotoSignedUrlTtl),
        );
      } else {
        _groupPhotoUrlCache.remove(storagePath);
      }
    }
  }

  Future<void> _ensureUserProfile(User user) async {
    final displayName = user.userMetadata?['display_name']?.toString() ??
        user.userMetadata?['full_name']?.toString() ??
        user.email?.split('@').first ??
        'user';
    final usernameBase = displayName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
    final username = '${usernameBase}_${user.id.substring(0, 8)}';
    final existingProfile = await _runWithSchemaCheck(
      () => _supabase.from('users').select('emoji').eq('id', user.id).maybeSingle(),
    );

    await _runWithSchemaCheck(
      () => _supabase.from('users').upsert({
        'id': user.id,
        'username': username,
        'display_name': displayName,
        'avatar_url': user.userMetadata?['avatar_url']?.toString(),
        'emoji': existingProfile?['emoji']?.toString() ?? user.userMetadata?['emoji']?.toString() ?? emojiForSeed(user.id),
      }),
    );
  }

  Map<String, dynamic> _normalizeGroupJson(Map<String, dynamic> json) {
    json['created_by'] = json['created_by']?.toString() ?? '';
    return json;
  }

  bool _looksLikeMissingLastActivityColumn(PostgrestException exception) {
    final message = exception.message.toLowerCase();
    return message.contains('last_activity_at') || exception.code == '42703';
  }

  Future<List<GroupPhotoModel>> _attachUploaderEmojis(List<GroupPhotoModel> photos) async {
    if (photos.isEmpty) {
      return photos;
    }

    final uploaderIds = photos.map((photo) => photo.uploadedBy).toSet().toList();
    final rows = await _runWithSchemaCheck(
      () => _supabase.from('users').select('id, emoji').inFilter('id', uploaderIds),
    );

    final emojisByUserId = <String, String>{};
    for (final row in rows as List<dynamic>) {
      final json = Map<String, dynamic>.from(row as Map);
      final userId = json['id']?.toString();
      if (userId == null || userId.isEmpty) continue;
      emojisByUserId[userId] = json['emoji']?.toString() ?? '🙂';
    }

    return photos
        .map(
          (photo) => photo.copyWith(
            uploaderEmoji: emojisByUserId[photo.uploadedBy] ?? photo.uploaderEmoji,
          ),
        )
        .toList();
  }

  Future<List<GroupPhotoModel>> _hydrateGroupPhotoUrls(List<GroupPhotoModel> photos) async {
    if (photos.isEmpty) {
      return photos;
    }

    final hydrated = await Future.wait(
      photos.map((photo) async {
        final storagePath = photo.storagePath.trim();
        if (storagePath.isEmpty) {
          return photo;
        }

        final displayUrl = await _resolveGroupPhotoDisplayUrl(
          storagePath: storagePath,
          fallbackUrl: photo.imageUrl,
        );
        return photo.copyWith(imageUrl: displayUrl);
      }),
    );

    return hydrated;
  }

  String publicGroupPhotoUrl(String storagePath) {
    final trimmedPath = storagePath.trim();
    if (trimmedPath.isEmpty) {
      return '';
    }

    return _supabase.storage.from('group-photos').getPublicUrl(trimmedPath);
  }

  Future<String?> resolveGroupPhotoSignedUrl(String storagePath) async {
    final trimmedPath = storagePath.trim();
    if (trimmedPath.isEmpty) {
      return null;
    }

    try {
      return await _supabase.storage.from('group-photos').createSignedUrl(
            trimmedPath,
            24 * 60 * 60,
          );
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> resolveGroupPhotoBytes(String storagePath) {
    final trimmedPath = storagePath.trim();
    if (trimmedPath.isEmpty) {
      return Future.value(null);
    }

    return _groupPhotoBytesCache.putIfAbsent(trimmedPath, () async {
      try {
        final bytes = await _supabase.storage.from('group-photos').download(trimmedPath);
        return Uint8List.fromList(bytes);
      } catch (_) {
        return null;
      }
    });
  }

  static const Duration _groupPhotoSignedUrlTtl = Duration(hours: 24);

  String _imageExtension(String path) {
    final cleanPath = path.split(RegExp(r'[\\/]+')).last.toLowerCase();
    if (cleanPath.endsWith('.png')) return 'png';
    if (cleanPath.endsWith('.webp')) return 'webp';
    if (cleanPath.endsWith('.heic')) return 'heic';
    return 'jpg';
  }

  String _imageContentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }
}

class _GroupPhotoUrlCacheEntry {
  const _GroupPhotoUrlCacheEntry({
    required this.url,
    required this.expiresAt,
  });

  final String url;
  final DateTime expiresAt;
}

class InviteLinks {
  const InviteLinks({
    required this.appLink,
    required this.webLink,
  });

  final String appLink;
  final String webLink;
}

class GroupInviteSetting {
  const GroupInviteSetting({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.invitePaused,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String inviteCode;
  final bool invitePaused;
  final DateTime createdAt;
}

class GroupsController extends StateNotifier<AsyncValue<List<GroupModel>>> {
  GroupsController(this._repository) : super(const AsyncValue.loading());

  final GroupsRepository _repository;

  Future<void> loadMyGroups() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repository.fetchMyGroups);
  }

  Future<GroupModel> createGroup({
    required String name,
    required String description,
    required String imageUrl,
  }) async {
    final group = await _repository.createGroup(
      name: name,
      description: description,
      imageUrl: imageUrl,
    );
    await loadMyGroups();
    return group;
  }
}
