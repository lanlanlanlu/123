import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';
import 'chat_reference.dart';

part 'chat_request.freezed.dart';
part 'chat_request.g.dart';

/// AI聊天请求模型
@freezed
class ChatRequest with _$ChatRequest {
  const factory ChatRequest({
    /// 查询文本
    required String query,
    
    /// 引用列表 - 包含笔记、标签和位置引用
    @Default([]) List<ChatReference> references,
    
    /// 是否使用重排序 - 默认开启
    @Default(true) bool useRerank,
    
    /// 重排序语言 - auto, english, multilingual
    @Default('auto') String rerankLanguage,
    
    /// 是否使用图谱 - 默认自动决定
    bool? useGraph,
    
    /// 聊天ID - 用于记忆功能
    @Default('') String chatId,
  }) = _ChatRequest;
  
  /// 从JSON创建
  factory ChatRequest.fromJson(Map<String, dynamic> json) => 
      _$ChatRequestFromJson(json);
} 