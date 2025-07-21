// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChatRequestImpl _$$ChatRequestImplFromJson(Map<String, dynamic> json) =>
    _$ChatRequestImpl(
      query: json['query'] as String,
      references: (json['references'] as List<dynamic>?)
              ?.map((e) => ChatReference.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      useRerank: json['useRerank'] as bool? ?? true,
      rerankLanguage: json['rerankLanguage'] as String? ?? 'auto',
      useGraph: json['useGraph'] as bool?,
      chatId: json['chatId'] as String? ?? '',
    );

Map<String, dynamic> _$$ChatRequestImplToJson(_$ChatRequestImpl instance) =>
    <String, dynamic>{
      'query': instance.query,
      'references': instance.references,
      'useRerank': instance.useRerank,
      'rerankLanguage': instance.rerankLanguage,
      'useGraph': instance.useGraph,
      'chatId': instance.chatId,
    };
