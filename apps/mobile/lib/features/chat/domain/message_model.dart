// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'message_model.freezed.dart';
part 'message_model.g.dart';

Map<String, int> _reactionsFromJson(Object? value) {
  if (value is Map) {
    return value.map((key, dynamic count) => MapEntry(key.toString(), (count as num).toInt()));
  }

  if (value is List) {
    final counts = <String, int>{};
    for (final entry in value) {
      if (entry is Map && entry['emoji'] != null) {
        final emoji = entry['emoji'].toString();
        counts[emoji] = (counts[emoji] ?? 0) + 1;
      }
    }
    return counts;
  }

  return const <String, int>{};
}

Map<String, dynamic> _reactionsToJson(Map<String, int> value) => value;

@freezed
sealed class MessageModel with _$MessageModel {
  const factory MessageModel({
    required String id,
    @JsonKey(name: 'group_id') required String groupId,
    @JsonKey(name: 'sender_id') required String senderId,
    @JsonKey(name: 'sender_name') required String senderName,
    required String content,
    required String type,
    @JsonKey(fromJson: _reactionsFromJson, toJson: _reactionsToJson)
    @Default(<String, int>{})
    Map<String, int> reactions,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _MessageModel;

  factory MessageModel.fromJson(Map<String, dynamic> json) => _$MessageModelFromJson(json);
}
