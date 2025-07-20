// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_reference.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ChatReference _$ChatReferenceFromJson(Map<String, dynamic> json) {
  return _ChatReference.fromJson(json);
}

/// @nodoc
mixin _$ChatReference {
  /// 引用ID (笔记ID或标签/地点名称)
  String get id => throw _privateConstructorUsedError;

  /// 引用标题/名称
  String get title => throw _privateConstructorUsedError;

  /// 引用类型
  ReferenceType get type => throw _privateConstructorUsedError;

  /// 引用内容 (可选，服务器填充)
  String? get content => throw _privateConstructorUsedError;

  /// Serializes this ChatReference to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ChatReference
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChatReferenceCopyWith<ChatReference> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatReferenceCopyWith<$Res> {
  factory $ChatReferenceCopyWith(
          ChatReference value, $Res Function(ChatReference) then) =
      _$ChatReferenceCopyWithImpl<$Res, ChatReference>;
  @useResult
  $Res call({String id, String title, ReferenceType type, String? content});
}

/// @nodoc
class _$ChatReferenceCopyWithImpl<$Res, $Val extends ChatReference>
    implements $ChatReferenceCopyWith<$Res> {
  _$ChatReferenceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChatReference
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? type = null,
    Object? content = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as ReferenceType,
      content: freezed == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChatReferenceImplCopyWith<$Res>
    implements $ChatReferenceCopyWith<$Res> {
  factory _$$ChatReferenceImplCopyWith(
          _$ChatReferenceImpl value, $Res Function(_$ChatReferenceImpl) then) =
      __$$ChatReferenceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String title, ReferenceType type, String? content});
}

/// @nodoc
class __$$ChatReferenceImplCopyWithImpl<$Res>
    extends _$ChatReferenceCopyWithImpl<$Res, _$ChatReferenceImpl>
    implements _$$ChatReferenceImplCopyWith<$Res> {
  __$$ChatReferenceImplCopyWithImpl(
      _$ChatReferenceImpl _value, $Res Function(_$ChatReferenceImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChatReference
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? type = null,
    Object? content = freezed,
  }) {
    return _then(_$ChatReferenceImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as ReferenceType,
      content: freezed == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ChatReferenceImpl
    with DiagnosticableTreeMixin
    implements _ChatReference {
  const _$ChatReferenceImpl(
      {required this.id,
      required this.title,
      required this.type,
      this.content});

  factory _$ChatReferenceImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChatReferenceImplFromJson(json);

  /// 引用ID (笔记ID或标签/地点名称)
  @override
  final String id;

  /// 引用标题/名称
  @override
  final String title;

  /// 引用类型
  @override
  final ReferenceType type;

  /// 引用内容 (可选，服务器填充)
  @override
  final String? content;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'ChatReference(id: $id, title: $title, type: $type, content: $content)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'ChatReference'))
      ..add(DiagnosticsProperty('id', id))
      ..add(DiagnosticsProperty('title', title))
      ..add(DiagnosticsProperty('type', type))
      ..add(DiagnosticsProperty('content', content));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatReferenceImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.content, content) || other.content == content));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, title, type, content);

  /// Create a copy of ChatReference
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatReferenceImplCopyWith<_$ChatReferenceImpl> get copyWith =>
      __$$ChatReferenceImplCopyWithImpl<_$ChatReferenceImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChatReferenceImplToJson(
      this,
    );
  }
}

abstract class _ChatReference implements ChatReference {
  const factory _ChatReference(
      {required final String id,
      required final String title,
      required final ReferenceType type,
      final String? content}) = _$ChatReferenceImpl;

  factory _ChatReference.fromJson(Map<String, dynamic> json) =
      _$ChatReferenceImpl.fromJson;

  /// 引用ID (笔记ID或标签/地点名称)
  @override
  String get id;

  /// 引用标题/名称
  @override
  String get title;

  /// 引用类型
  @override
  ReferenceType get type;

  /// 引用内容 (可选，服务器填充)
  @override
  String? get content;

  /// Create a copy of ChatReference
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChatReferenceImplCopyWith<_$ChatReferenceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ChatMessageWithReferences _$ChatMessageWithReferencesFromJson(
    Map<String, dynamic> json) {
  return _ChatMessageWithReferences.fromJson(json);
}

/// @nodoc
mixin _$ChatMessageWithReferences {
  /// 消息文本
  String get text => throw _privateConstructorUsedError;

  /// 消息引用列表
  List<ChatReference> get references => throw _privateConstructorUsedError;

  /// 消息发送时间
  DateTime get timestamp => throw _privateConstructorUsedError;

  /// Serializes this ChatMessageWithReferences to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ChatMessageWithReferences
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChatMessageWithReferencesCopyWith<ChatMessageWithReferences> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatMessageWithReferencesCopyWith<$Res> {
  factory $ChatMessageWithReferencesCopyWith(ChatMessageWithReferences value,
          $Res Function(ChatMessageWithReferences) then) =
      _$ChatMessageWithReferencesCopyWithImpl<$Res, ChatMessageWithReferences>;
  @useResult
  $Res call({String text, List<ChatReference> references, DateTime timestamp});
}

/// @nodoc
class _$ChatMessageWithReferencesCopyWithImpl<$Res,
        $Val extends ChatMessageWithReferences>
    implements $ChatMessageWithReferencesCopyWith<$Res> {
  _$ChatMessageWithReferencesCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChatMessageWithReferences
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? text = null,
    Object? references = null,
    Object? timestamp = null,
  }) {
    return _then(_value.copyWith(
      text: null == text
          ? _value.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
      references: null == references
          ? _value.references
          : references // ignore: cast_nullable_to_non_nullable
              as List<ChatReference>,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChatMessageWithReferencesImplCopyWith<$Res>
    implements $ChatMessageWithReferencesCopyWith<$Res> {
  factory _$$ChatMessageWithReferencesImplCopyWith(
          _$ChatMessageWithReferencesImpl value,
          $Res Function(_$ChatMessageWithReferencesImpl) then) =
      __$$ChatMessageWithReferencesImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String text, List<ChatReference> references, DateTime timestamp});
}

/// @nodoc
class __$$ChatMessageWithReferencesImplCopyWithImpl<$Res>
    extends _$ChatMessageWithReferencesCopyWithImpl<$Res,
        _$ChatMessageWithReferencesImpl>
    implements _$$ChatMessageWithReferencesImplCopyWith<$Res> {
  __$$ChatMessageWithReferencesImplCopyWithImpl(
      _$ChatMessageWithReferencesImpl _value,
      $Res Function(_$ChatMessageWithReferencesImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChatMessageWithReferences
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? text = null,
    Object? references = null,
    Object? timestamp = null,
  }) {
    return _then(_$ChatMessageWithReferencesImpl(
      text: null == text
          ? _value.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
      references: null == references
          ? _value._references
          : references // ignore: cast_nullable_to_non_nullable
              as List<ChatReference>,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ChatMessageWithReferencesImpl
    with DiagnosticableTreeMixin
    implements _ChatMessageWithReferences {
  const _$ChatMessageWithReferencesImpl(
      {required this.text,
      final List<ChatReference> references = const [],
      required this.timestamp})
      : _references = references;

  factory _$ChatMessageWithReferencesImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChatMessageWithReferencesImplFromJson(json);

  /// 消息文本
  @override
  final String text;

  /// 消息引用列表
  final List<ChatReference> _references;

  /// 消息引用列表
  @override
  @JsonKey()
  List<ChatReference> get references {
    if (_references is EqualUnmodifiableListView) return _references;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_references);
  }

  /// 消息发送时间
  @override
  final DateTime timestamp;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'ChatMessageWithReferences(text: $text, references: $references, timestamp: $timestamp)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'ChatMessageWithReferences'))
      ..add(DiagnosticsProperty('text', text))
      ..add(DiagnosticsProperty('references', references))
      ..add(DiagnosticsProperty('timestamp', timestamp));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatMessageWithReferencesImpl &&
            (identical(other.text, text) || other.text == text) &&
            const DeepCollectionEquality()
                .equals(other._references, _references) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, text,
      const DeepCollectionEquality().hash(_references), timestamp);

  /// Create a copy of ChatMessageWithReferences
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatMessageWithReferencesImplCopyWith<_$ChatMessageWithReferencesImpl>
      get copyWith => __$$ChatMessageWithReferencesImplCopyWithImpl<
          _$ChatMessageWithReferencesImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChatMessageWithReferencesImplToJson(
      this,
    );
  }
}

abstract class _ChatMessageWithReferences implements ChatMessageWithReferences {
  const factory _ChatMessageWithReferences(
      {required final String text,
      final List<ChatReference> references,
      required final DateTime timestamp}) = _$ChatMessageWithReferencesImpl;

  factory _ChatMessageWithReferences.fromJson(Map<String, dynamic> json) =
      _$ChatMessageWithReferencesImpl.fromJson;

  /// 消息文本
  @override
  String get text;

  /// 消息引用列表
  @override
  List<ChatReference> get references;

  /// 消息发送时间
  @override
  DateTime get timestamp;

  /// Create a copy of ChatMessageWithReferences
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChatMessageWithReferencesImplCopyWith<_$ChatMessageWithReferencesImpl>
      get copyWith => throw _privateConstructorUsedError;
}
