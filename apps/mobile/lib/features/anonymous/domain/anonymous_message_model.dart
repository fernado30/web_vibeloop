// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'anonymous_message_model.freezed.dart';
part 'anonymous_message_model.g.dart';

Map<String, int> _anonymousReactionsFromJson(Object? value) {
  if (value is Map) {
    return value.map((key, dynamic count) => MapEntry(key.toString(), (count as num).toInt()));
  }
  return const <String, int>{};
}

Map<String, dynamic> _anonymousReactionsToJson(Map<String, int> value) => value;

@freezed
sealed class AnonymousMessageModel with _$AnonymousMessageModel {
  const factory AnonymousMessageModel({
    required String id,
    @JsonKey(name: 'group_id') required String groupId,
    required String content,
    @JsonKey(fromJson: _anonymousReactionsFromJson, toJson: _anonymousReactionsToJson)
    @Default(<String, int>{})
    Map<String, int> reactions,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _AnonymousMessageModel;

  factory AnonymousMessageModel.fromJson(Map<String, dynamic> json) => _$AnonymousMessageModelFromJson(json);
}
