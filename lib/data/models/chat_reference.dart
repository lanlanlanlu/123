import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part 'chat_reference.freezed.dart';
part 'chat_reference.g.dart';

/// 聊天引用类型
enum ReferenceType {
  /// 笔记引用
  note,
  
  /// 标签引用
  tag,
  
  /// 地点引用
  location
}

/// 聊天引用模型 - 用于在AI聊天中引用内容
@freezed
class ChatReference with _$ChatReference {
  const factory ChatReference({
    /// 引用ID (笔记ID或标签/地点名称)
    required String id,
    
    /// 引用标题/名称
    required String title,
    
    /// 引用类型
    required ReferenceType type,
    
    /// 引用内容 (可选，服务器填充)
    String? content,
  }) = _ChatReference;
  
  /// 从JSON创建
  factory ChatReference.fromJson(Map<String, dynamic> json) => 
      _$ChatReferenceFromJson(json);
}

/// 包含引用的聊天消息
@freezed
class ChatMessageWithReferences with _$ChatMessageWithReferences {
  const factory ChatMessageWithReferences({
    /// 消息文本
    required String text,
    
    /// 消息引用列表
    @Default([]) List<ChatReference> references,
    
    /// 消息发送时间
    required DateTime timestamp,
  }) = _ChatMessageWithReferences;
  
  /// 从JSON创建
  factory ChatMessageWithReferences.fromJson(Map<String, dynamic> json) => 
      _$ChatMessageWithReferencesFromJson(json);
} 