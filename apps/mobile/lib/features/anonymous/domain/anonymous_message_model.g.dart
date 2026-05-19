// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'anonymous_message_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AnonymousMessageModelImpl _$$AnonymousMessageModelImplFromJson(
        Map<String, dynamic> json) =>
    _$AnonymousMessageModelImpl(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      content: json['content'] as String,
      reactions: json['reactions'] == null
          ? const <String, int>{}
          : _anonymousReactionsFromJson(json['reactions']),
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$$AnonymousMessageModelImplToJson(
        _$AnonymousMessageModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'group_id': instance.groupId,
      'content': instance.content,
      'reactions': _anonymousReactionsToJson(instance.reactions),
      'created_at': instance.createdAt.toIso8601String(),
    };
