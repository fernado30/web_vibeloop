// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'anonymous_message_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

AnonymousMessageModel _$AnonymousMessageModelFromJson(
    Map<String, dynamic> json) {
  return _AnonymousMessageModel.fromJson(json);
}

/// @nodoc
mixin _$AnonymousMessageModel {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'group_id')
  String get groupId => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;
  @JsonKey(
      fromJson: _anonymousReactionsFromJson, toJson: _anonymousReactionsToJson)
  Map<String, int> get reactions => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this AnonymousMessageModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AnonymousMessageModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AnonymousMessageModelCopyWith<AnonymousMessageModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AnonymousMessageModelCopyWith<$Res> {
  factory $AnonymousMessageModelCopyWith(AnonymousMessageModel value,
          $Res Function(AnonymousMessageModel) then) =
      _$AnonymousMessageModelCopyWithImpl<$Res, AnonymousMessageModel>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'group_id') String groupId,
      String content,
      @JsonKey(
          fromJson: _anonymousReactionsFromJson,
          toJson: _anonymousReactionsToJson)
      Map<String, int> reactions,
      @JsonKey(name: 'created_at') DateTime createdAt});
}

/// @nodoc
class _$AnonymousMessageModelCopyWithImpl<$Res,
        $Val extends AnonymousMessageModel>
    implements $AnonymousMessageModelCopyWith<$Res> {
  _$AnonymousMessageModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AnonymousMessageModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? groupId = null,
    Object? content = null,
    Object? reactions = null,
    Object? createdAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      groupId: null == groupId
          ? _value.groupId
          : groupId // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      reactions: null == reactions
          ? _value.reactions
          : reactions // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AnonymousMessageModelImplCopyWith<$Res>
    implements $AnonymousMessageModelCopyWith<$Res> {
  factory _$$AnonymousMessageModelImplCopyWith(
          _$AnonymousMessageModelImpl value,
          $Res Function(_$AnonymousMessageModelImpl) then) =
      __$$AnonymousMessageModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'group_id') String groupId,
      String content,
      @JsonKey(
          fromJson: _anonymousReactionsFromJson,
          toJson: _anonymousReactionsToJson)
      Map<String, int> reactions,
      @JsonKey(name: 'created_at') DateTime createdAt});
}

/// @nodoc
class __$$AnonymousMessageModelImplCopyWithImpl<$Res>
    extends _$AnonymousMessageModelCopyWithImpl<$Res,
        _$AnonymousMessageModelImpl>
    implements _$$AnonymousMessageModelImplCopyWith<$Res> {
  __$$AnonymousMessageModelImplCopyWithImpl(_$AnonymousMessageModelImpl _value,
      $Res Function(_$AnonymousMessageModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of AnonymousMessageModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? groupId = null,
    Object? content = null,
    Object? reactions = null,
    Object? createdAt = null,
  }) {
    return _then(_$AnonymousMessageModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      groupId: null == groupId
          ? _value.groupId
          : groupId // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      reactions: null == reactions
          ? _value._reactions
          : reactions // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AnonymousMessageModelImpl implements _AnonymousMessageModel {
  const _$AnonymousMessageModelImpl(
      {required this.id,
      @JsonKey(name: 'group_id') required this.groupId,
      required this.content,
      @JsonKey(
          fromJson: _anonymousReactionsFromJson,
          toJson: _anonymousReactionsToJson)
      final Map<String, int> reactions = const <String, int>{},
      @JsonKey(name: 'created_at') required this.createdAt})
      : _reactions = reactions;

  factory _$AnonymousMessageModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$AnonymousMessageModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'group_id')
  final String groupId;
  @override
  final String content;
  final Map<String, int> _reactions;
  @override
  @JsonKey(
      fromJson: _anonymousReactionsFromJson, toJson: _anonymousReactionsToJson)
  Map<String, int> get reactions {
    if (_reactions is EqualUnmodifiableMapView) return _reactions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_reactions);
  }

  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @override
  String toString() {
    return 'AnonymousMessageModel(id: $id, groupId: $groupId, content: $content, reactions: $reactions, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AnonymousMessageModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.groupId, groupId) || other.groupId == groupId) &&
            (identical(other.content, content) || other.content == content) &&
            const DeepCollectionEquality()
                .equals(other._reactions, _reactions) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, groupId, content,
      const DeepCollectionEquality().hash(_reactions), createdAt);

  /// Create a copy of AnonymousMessageModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AnonymousMessageModelImplCopyWith<_$AnonymousMessageModelImpl>
      get copyWith => __$$AnonymousMessageModelImplCopyWithImpl<
          _$AnonymousMessageModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AnonymousMessageModelImplToJson(
      this,
    );
  }
}

abstract class _AnonymousMessageModel implements AnonymousMessageModel {
  const factory _AnonymousMessageModel(
          {required final String id,
          @JsonKey(name: 'group_id') required final String groupId,
          required final String content,
          @JsonKey(
              fromJson: _anonymousReactionsFromJson,
              toJson: _anonymousReactionsToJson)
          final Map<String, int> reactions,
          @JsonKey(name: 'created_at') required final DateTime createdAt}) =
      _$AnonymousMessageModelImpl;

  factory _AnonymousMessageModel.fromJson(Map<String, dynamic> json) =
      _$AnonymousMessageModelImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'group_id')
  String get groupId;
  @override
  String get content;
  @override
  @JsonKey(
      fromJson: _anonymousReactionsFromJson, toJson: _anonymousReactionsToJson)
  Map<String, int> get reactions;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;

  /// Create a copy of AnonymousMessageModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AnonymousMessageModelImplCopyWith<_$AnonymousMessageModelImpl>
      get copyWith => throw _privateConstructorUsedError;
}
