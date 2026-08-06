import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/safety/perspective_service.dart';
import '../../settings/data/safety_repository.dart';
import '../domain/message_model.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(Supabase.instance.client);
});

class ChatRepository {
  ChatRepository(this._client);

  final SupabaseClient _client;

  SupabaseClient get _supabase => _client;

  Future<MessageModel> _fetchMessageById(String messageId) async {
    dynamic row;
    try {
      row = await _supabase
          .from('messages')
          .select('id, group_id, sender_id, content, type, is_flagged, created_at, sender:users(display_name, emoji), reactions:reactions(emoji)')
          .eq('id', messageId)
          .maybeSingle();
    } catch (_) {
      row = await _supabase
          .from('messages')
          .select('id, group_id, sender_id, content, type, created_at, sender:users(display_name, emoji), reactions:reactions(emoji)')
          .eq('id', messageId)
          .maybeSingle();
    }

    if (row == null) {
      throw StateError('No se pudo cargar el mensaje.');
    }

    final json = Map<String, dynamic>.from(row as Map);
    final isFlagged = json['is_flagged'] == true;
    if (isFlagged) {
      throw StateError('Mensaje no disponible.');
    }
    final sender = json['sender'] as Map<String, dynamic>?;
    json['sender_name'] = sender?['emoji']?.toString() ?? '🙂';
    json['reactions'] = _reactionCounts(json['reactions']);
    final message = MessageModel.fromJson(json);
    try {
      final filtered = await SafetyRepository(_supabase).filterMessages([message]);
      if (filtered.isNotEmpty) {
        return filtered.first;
      }
    } catch (_) {
      // Fallback to the raw message if safety filters are unavailable.
    }
    return message;
  }

  Future<List<MessageModel>> fetchMessages(String groupId) async {
    dynamic rows;
    try {
      rows = await _supabase
          .from('messages')
          .select('id, group_id, sender_id, content, type, is_flagged, created_at, sender:users(display_name, emoji), reactions:reactions(emoji)')
          .eq('group_id', groupId)
          .order('created_at', ascending: false);
    } catch (_) {
      rows = await _supabase
          .from('messages')
          .select('id, group_id, sender_id, content, type, created_at, sender:users(display_name, emoji), reactions:reactions(emoji)')
          .eq('group_id', groupId)
          .order('created_at', ascending: false);
    }

    final messages = (rows as List<dynamic>).map((row) {
      final json = Map<String, dynamic>.from(row as Map);
      final isFlagged = json['is_flagged'] == true;
      final content = json['content']?.toString() ?? '';
      if (isFlagged || PerspectiveService.isLocalProfane(content)) {
        return null;
      }
      final sender = json['sender'] as Map<String, dynamic>?;
      json['sender_name'] = sender?['emoji']?.toString() ?? '🙂';
      json['reactions'] = _reactionCounts(json['reactions']);
      return MessageModel.fromJson(json);
    }).whereType<MessageModel>().toList();

    try {
      return await SafetyRepository(_supabase).filterMessages(messages);
    } catch (_) {
      return messages;
    }
  }

  Future<void> sendMessage(String groupId, String content, String type) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const AuthException('Debes iniciar sesión para enviar mensajes.');
    }

    final perspective = await PerspectiveService.analyze(content);
    Map<String, dynamic>? inserted;

    try {
      inserted = await _supabase.from('messages').insert({
        'group_id': groupId,
        'sender_id': user.id,
        'content': content,
        'type': type,
        'is_flagged': perspective.isToxic,
      }).select('id').maybeSingle();
    } catch (_) {
      inserted = await _supabase.from('messages').insert({
        'group_id': groupId,
        'sender_id': user.id,
        'content': content,
        'type': type,
      }).select('id').maybeSingle();
    }

    if (perspective.isToxic && inserted != null && inserted['id'] != null) {
      final messageId = inserted['id'].toString();
      try {
        await _supabase.from('content_reports').insert({
          'reporter_id': user.id,
          'target_type': 'message',
          'target_id': messageId,
          'reason': 'Google Perspective AI: Contenido ${perspective.attribute} (${(perspective.score * 100).round()}%)',
          'details': 'Origen: Chat de Grupo | ID Grupo: $groupId | Score: ${(perspective.score * 100).round()}%',
          'content_snapshot': content,
          'status': 'pending',
        });
      } catch (e) {
        // Log report insertion error gracefully so sending flow never crashes
      }
    }
  }

  Future<void> editMessage(String messageId, String content) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const AuthException('Debes iniciar sesión para editar mensajes.');
    }

    await _supabase
        .from('messages')
        .update({'content': content})
        .eq('id', messageId)
        .eq('sender_id', user.id);
  }

  Future<void> deleteMessage(String messageId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const AuthException('Debes iniciar sesión para eliminar mensajes.');
    }

    await _supabase.from('messages').delete().eq('id', messageId).eq('sender_id', user.id);
  }

  Future<void> reactToMessage(String messageId, String emoji) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const AuthException('Debes iniciar sesión para reaccionar.');
    }

    await _supabase.from('reactions').upsert({
      'message_id': messageId,
      'user_id': user.id,
      'emoji': emoji,
    });
  }

  Stream<List<MessageModel>> watchMessages(String groupId) {
    final controller = StreamController<List<MessageModel>>.broadcast();
    final channel = _supabase.channel('messages-$groupId');
    var cache = <MessageModel>[]; 
    var loaded = false;

    Future<void> emit() async {
      if (!controller.isClosed) {
        cache = await fetchMessages(groupId);
        loaded = true;
        controller.add(cache);
      }
    }

    Future<void> refreshSingleMessage(String messageId) async {
      if (!loaded || controller.isClosed) {
        await emit();
        return;
      }

      try {
        final message = await _fetchMessageById(messageId);
        final existingIndex = cache.indexWhere((item) => item.id == message.id);

        if (existingIndex == -1) {
          cache = [message, ...cache];
        } else {
          cache = [
            ...cache.take(existingIndex),
            message,
            ...cache.skip(existingIndex + 1),
          ];
        }
      } catch (_) {
        cache = cache.where((item) => item.id != messageId).toList();
      }

      if (!controller.isClosed) {
        controller.add(cache);
      }
    }

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(column: 'group_id', value: groupId, type: PostgresChangeFilterType.eq),
      callback: (payload) {
        final messageId = payload.newRecord['id']?.toString();
        if (messageId == null || messageId.isEmpty) {
          emit();
          return;
        }
        refreshSingleMessage(messageId);
      },
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(column: 'group_id', value: groupId, type: PostgresChangeFilterType.eq),
      callback: (payload) {
        final messageId = payload.newRecord['id']?.toString();
        if (messageId == null || messageId.isEmpty) {
          emit();
          return;
        }
        refreshSingleMessage(messageId);
      },
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(column: 'group_id', value: groupId, type: PostgresChangeFilterType.eq),
      callback: (_) => emit(),
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'reactions',
      callback: (_) => emit(),
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'reactions',
      callback: (_) => emit(),
    );

    channel.subscribe();
    emit();

    controller.onCancel = () async {
      channel.unsubscribe();
      await controller.close();
    };

    return controller.stream;
  }
}

Map<String, int> _reactionCounts(dynamic raw) {
  final counts = <String, int>{};
  if (raw is List) {
    for (final item in raw) {
      if (item is Map && item['emoji'] != null) {
        final emoji = item['emoji'].toString();
        counts[emoji] = (counts[emoji] ?? 0) + 1;
      }
    }
  }
  return counts;
}
