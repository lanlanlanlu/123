// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_reference.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChatReferenceImpl _$$ChatReferenceImplFromJson(Map<String, dynamic> json) =>
    _$ChatReferenceImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      type: $enumDecode(_$ReferenceTypeEnumMap, json['type']),
      content: json['content'] as String?,
    );

Map<String, dynamic> _$$ChatReferenceImplToJson(_$ChatReferenceImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'type': _$ReferenceTypeEnumMap[instance.type]!,
      'content': instance.content,
    };

const _$ReferenceTypeEnumMap = {
  ReferenceType.note: 'note',
  ReferenceType.tag: 'tag',
  ReferenceType.location: 'location',
};

_$ChatMessageWithReferencesImpl _$$ChatMessageWithReferencesImplFromJson(
        Map<String, dynamic> json) =>
    _$ChatMessageWithReferencesImpl(
      text: json['text'] as String,
      references: (json['references'] as List<dynamic>?)
              ?.map((e) => ChatReference.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$$ChatMessageWithReferencesImplToJson(
        _$ChatMessageWithReferencesImpl instance) =>
    <String, dynamic>{
      'text': instance.text,
      'references': instance.references,
      'timestamp': instance.timestamp.toIso8601String(),
    };
