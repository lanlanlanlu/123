// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ChatRequest _$ChatRequestFromJson(Map<String, dynamic> json) {
  return _ChatRequest.fromJson(json);
}

/// @nodoc
mixin _$ChatRequest {
  /// 查询文本
  String get query => throw _privateConstructorUsedError;

  /// 引用列表 - 包含笔记、标签和位置引用
  List<ChatReference> get references => throw _privateConstructorUsedError;

  /// 是否使用重排序 - 默认开启
  bool get useRerank => throw _privateConstructorUsedError;

  /// 重排序语言 - auto, english, multilingual
  String get rerankLanguage => throw _privateConstructorUsedError;

  /// 是否使用图谱 - 默认自动决定
  bool? get useGraph => throw _privateConstructorUsedError;

  /// 聊天ID - 用于记忆功能
  String get chatId => throw _privateConstructorUsedError;

  /// 模型名称 - 指定要使用的模型
  String get model => throw _privateConstructorUsedError;

  /// Serializes this ChatRequest to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ChatRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChatRequestCopyWith<ChatRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatRequestCopyWith<$Res> {
  factory $ChatRequestCopyWith(
          ChatRequest value, $Res Function(ChatRequest) then) =
      _$ChatRequestCopyWithImpl<$Res, ChatRequest>;
  @useResult
  $Res call(
      {String query,
      List<ChatReference> references,
      bool useRerank,
      String rerankLanguage,
      bool? useGraph,
      String chatId,
      String model});
}

/// @nodoc
class _$ChatRequestCopyWithImpl<$Res, $Val extends ChatRequest>
    implements $ChatRequestCopyWith<$Res> {
  _$ChatRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChatRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? query = null,
    Object? references = null,
    Object? useRerank = null,
    Object? rerankLanguage = null,
    Object? useGraph = freezed,
    Object? chatId = null,
    Object? model = null,
  }) {
    return _then(_value.copyWith(
      query: null == query
          ? _value.query
          : query // ignore: cast_nullable_to_non_nullable
              as String,
      references: null == references
          ? _value.references
          : references // ignore: cast_nullable_to_non_nullable
              as List<ChatReference>,
      useRerank: null == useRerank
          ? _value.useRerank
          : useRerank // ignore: cast_nullable_to_non_nullable
              as bool,
      rerankLanguage: null == rerankLanguage
          ? _value.rerankLanguage
          : rerankLanguage // ignore: cast_nullable_to_non_nullable
              as String,
      useGraph: freezed == useGraph
          ? _value.useGraph
          : useGraph // ignore: cast_nullable_to_non_nullable
              as bool?,
      chatId: null == chatId
          ? _value.chatId
          : chatId // ignore: cast_nullable_to_non_nullable
              as String,
      model: null == model
          ? _value.model
          : model // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChatRequestImplCopyWith<$Res>
    implements $ChatRequestCopyWith<$Res> {
  factory _$$ChatRequestImplCopyWith(
          _$ChatRequestImpl value, $Res Function(_$ChatRequestImpl) then) =
      __$$ChatRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String query,
      List<ChatReference> references,
      bool useRerank,
      String rerankLanguage,
      bool? useGraph,
      String chatId,
      String model});
}

/// @nodoc
class __$$ChatRequestImplCopyWithImpl<$Res>
    extends _$ChatRequestCopyWithImpl<$Res, _$ChatRequestImpl>
    implements _$$ChatRequestImplCopyWith<$Res> {
  __$$ChatRequestImplCopyWithImpl(
      _$ChatRequestImpl _value, $Res Function(_$ChatRequestImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChatRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? query = null,
    Object? references = null,
    Object? useRerank = null,
    Object? rerankLanguage = null,
    Object? useGraph = freezed,
    Object? chatId = null,
    Object? model = null,
  }) {
    return _then(_$ChatRequestImpl(
      query: null == query
          ? _value.query
          : query // ignore: cast_nullable_to_non_nullable
              as String,
      references: null == references
          ? _value._references
          : references // ignore: cast_nullable_to_non_nullable
              as List<ChatReference>,
      useRerank: null == useRerank
          ? _value.useRerank
          : useRerank // ignore: cast_nullable_to_non_nullable
              as bool,
      rerankLanguage: null == rerankLanguage
          ? _value.rerankLanguage
          : rerankLanguage // ignore: cast_nullable_to_non_nullable
              as String,
      useGraph: freezed == useGraph
          ? _value.useGraph
          : useGraph // ignore: cast_nullable_to_non_nullable
              as bool?,
      chatId: null == chatId
          ? _value.chatId
          : chatId // ignore: cast_nullable_to_non_nullable
              as String,
      model: null == model
          ? _value.model
          : model // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ChatRequestImpl with DiagnosticableTreeMixin implements _ChatRequest {
  const _$ChatRequestImpl(
      {required this.query,
      final List<ChatReference> references = const [],
      this.useRerank = true,
      this.rerankLanguage = 'auto',
      this.useGraph,
      this.chatId = '',
      this.model = 'gemini-2.5-flash'})
      : _references = references;

  factory _$ChatRequestImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChatRequestImplFromJson(json);

  /// 查询文本
  @override
  final String query;

  /// 引用列表 - 包含笔记、标签和位置引用
  final List<ChatReference> _references;

  /// 引用列表 - 包含笔记、标签和位置引用
  @override
  @JsonKey()
  List<ChatReference> get references {
    if (_references is EqualUnmodifiableListView) return _references;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_references);
  }

  /// 是否使用重排序 - 默认开启
  @override
  @JsonKey()
  final bool useRerank;

  /// 重排序语言 - auto, english, multilingual
  @override
  @JsonKey()
  final String rerankLanguage;

  /// 是否使用图谱 - 默认自动决定
  @override
  final bool? useGraph;

  /// 聊天ID - 用于记忆功能
  @override
  @JsonKey()
  final String chatId;

  /// 模型名称 - 指定要使用的模型
  @override
  @JsonKey()
  final String model;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'ChatRequest(query: $query, references: $references, useRerank: $useRerank, rerankLanguage: $rerankLanguage, useGraph: $useGraph, chatId: $chatId, model: $model)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'ChatRequest'))
      ..add(DiagnosticsProperty('query', query))
      ..add(DiagnosticsProperty('references', references))
      ..add(DiagnosticsProperty('useRerank', useRerank))
      ..add(DiagnosticsProperty('rerankLanguage', rerankLanguage))
      ..add(DiagnosticsProperty('useGraph', useGraph))
      ..add(DiagnosticsProperty('chatId', chatId))
      ..add(DiagnosticsProperty('model', model));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatRequestImpl &&
            (identical(other.query, query) || other.query == query) &&
            const DeepCollectionEquality()
                .equals(other._references, _references) &&
            (identical(other.useRerank, useRerank) ||
                other.useRerank == useRerank) &&
            (identical(other.rerankLanguage, rerankLanguage) ||
                other.rerankLanguage == rerankLanguage) &&
            (identical(other.useGraph, useGraph) ||
                other.useGraph == useGraph) &&
            (identical(other.chatId, chatId) || other.chatId == chatId) &&
            (identical(other.model, model) || other.model == model));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      query,
      const DeepCollectionEquality().hash(_references),
      useRerank,
      rerankLanguage,
      useGraph,
      chatId,
      model);

  /// Create a copy of ChatRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatRequestImplCopyWith<_$ChatRequestImpl> get copyWith =>
      __$$ChatRequestImplCopyWithImpl<_$ChatRequestImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChatRequestImplToJson(
      this,
    );
  }
}

abstract class _ChatRequest implements ChatRequest {
  const factory _ChatRequest(
      {required final String query,
      final List<ChatReference> references,
      final bool useRerank,
      final String rerankLanguage,
      final bool? useGraph,
      final String chatId,
      final String model}) = _$ChatRequestImpl;

  factory _ChatRequest.fromJson(Map<String, dynamic> json) =
      _$ChatRequestImpl.fromJson;

  /// 查询文本
  @override
  String get query;

  /// 引用列表 - 包含笔记、标签和位置引用
  @override
  List<ChatReference> get references;

  /// 是否使用重排序 - 默认开启
  @override
  bool get useRerank;

  /// 重排序语言 - auto, english, multilingual
  @override
  String get rerankLanguage;

  /// 是否使用图谱 - 默认自动决定
  @override
  bool? get useGraph;

  /// 聊天ID - 用于记忆功能
  @override
  String get chatId;

  /// 模型名称 - 指定要使用的模型
  @override
  String get model;

  /// Create a copy of ChatRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChatRequestImplCopyWith<_$ChatRequestImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
