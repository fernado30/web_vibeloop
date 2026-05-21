import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/invite_link_config.dart';
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

  SupabaseClient get _supabase => _client;

  Future<T> _withInviteCodeHeader<T>(
    String inviteCode,
    Future<T> Function() action,
  ) async {
    final previousHeaders = Map<String, String>.from(_supabase.headers);
    try {
      _supabase.headers = {
        ...previousHeaders,
        'x-invite-code': inviteCode,
      };
      return await action();
    } finally {
      _supabase.headers = previousHeaders;
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

    final rows = await _runWithSchemaCheck(
      () => _supabase
          .from('groups')
          .select('id, name, description, image_url, created_by, invite_code, created_at, group_members!inner(user_id)')
          .eq('group_members.user_id', user.id)
          .order('created_at', ascending: false),
    );

    final groups = (rows as List<dynamic>).map((row) {
      final json = Map<String, dynamic>.from(row as Map);
      json['member_count'] = 0;
      return GroupModel.fromJson(json);
    }).toList();

    return Future.wait(groups.map((group) async {
      final memberCount = await _countMembers(group.id);
      return group.copyWith(memberCount: memberCount);
    }));
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
    return GroupModel.fromJson(groupJson);
  }

  Future<GroupModel> getGroupById(String id) async {
    final row = await _runWithSchemaCheck(
      () => _supabase
          .from('groups')
          .select('id, name, description, image_url, created_by, invite_code, created_at, group_members(user_id)')
          .eq('id', id)
          .single(),
    );

    final json = Map<String, dynamic>.from(row);
    json['member_count'] = await _countMembers(id);
    return GroupModel.fromJson(json);
  }

  Future<InviteLinks> generateInviteLinks(String groupId) async {
    final row = await _runWithSchemaCheck(() => _supabase.from('groups').select('invite_code').eq('id', groupId).single());
    final inviteCode = row['invite_code'] as String;
    final config = await InviteLinkConfig.load();

    final user = _supabase.auth.currentUser;
    final profile = user == null
        ? null
        : await _runWithSchemaCheck(
            () => _supabase.from('users').select('display_name').eq('id', user.id).maybeSingle(),
          );

    final displayName = (profile?['display_name']?.toString() ??
            user?.userMetadata?['display_name']?.toString() ??
            user?.email?.split('@').first ??
            'invitado')
        .trim();
    final inviteNumber = 1000 + Random().nextInt(9000);
    final token = '${_safeSlug(displayName)}-$inviteNumber-$inviteCode';
    final normalizedWebUrl = config.webUrl.replaceAll(RegExp(r'/+$'), '');
    final appLink = '$normalizedWebUrl/open/$token';
    final webLink = '$normalizedWebUrl/invite/$token';

    return InviteLinks(appLink: appLink, webLink: webLink);
  }

  Future<GroupModel> getGroupByInviteCode(String inviteCode) async {
    final row = await _runWithSchemaCheck(
      () => _withInviteCodeHeader(
        inviteCode,
        () => _supabase
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

    final json = Map<String, dynamic>.from(row);
    json['member_count'] = await _countMembers(json['id'] as String);
    return GroupModel.fromJson(json);
  }

  Future<void> joinGroup(String groupId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw AuthException('No hay una sesion activa.');
    }

    await _ensureUserProfile(user);
    await _runWithSchemaCheck(
      () => _supabase.from('group_members').upsert(
            {
              'group_id': groupId,
              'user_id': user.id,
              'role': 'member',
            },
            onConflict: 'group_id,user_id',
            ignoreDuplicates: true,
          ),
    );
  }

  Future<int> _countMembers(String groupId) async {
    final rows = await _runWithSchemaCheck(() => _supabase.from('group_members').select('id').eq('group_id', groupId));
    return (rows as List<dynamic>).length;
  }

  Future<void> _ensureUserProfile(User user) async {
    final displayName = user.userMetadata?['display_name']?.toString() ??
        user.userMetadata?['full_name']?.toString() ??
        user.email?.split('@').first ??
        'user';
    final usernameBase = displayName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
    final username = '${usernameBase}_${user.id.substring(0, 8)}';

    await _runWithSchemaCheck(
      () => _supabase.from('users').upsert({
        'id': user.id,
        'username': username,
        'display_name': displayName,
        'avatar_url': user.userMetadata?['avatar_url']?.toString(),
      }),
    );
  }
}

class InviteLinks {
  const InviteLinks({
    required this.appLink,
    required this.webLink,
  });

  final String appLink;
  final String webLink;
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
