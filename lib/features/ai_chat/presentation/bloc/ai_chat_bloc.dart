import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dash_chat_2/dash_chat_2.dart' as dash;
import 'package:flutter/foundation.dart';

import 'package:record_app/data/repository/ai_chat_repository.dart'; // 引入 Repository
import 'package:record_app/data/models/chat_reference.dart'; // 引入引用模型
import 'ai_chat_event.dart';
import 'ai_chat_state.dart';

/// 消息变更回调类型定义
typedef MessageChangeCallback = void Function();

class AiChatBloc extends Bloc<AiChatEvent, AiChatState> {
  // 添加一个 Repository 依赖
  final AiChatRepository aiChatRepository;
  
  // 消息变更回调
  MessageChangeCallback? onMessageAdded;
  
  // 清除聊天回调
  VoidCallback? onChatCleared;
  
  // 添加聊天ID
  String? chatHistoryId;

  AiChatBloc({
    required this.aiChatRepository, 
    this.onMessageAdded,
    this.onChatCleared,
    this.chatHistoryId,
  }) : super(const AiChatState()) {
    on<AiChatInitialized>(_onInitialized);
    on<AiChatInitializedWithHistory>(_onInitializedWithHistory); // 处理带历史消息的初始化
    on<AiChatMessageSent>(_onMessageSent); // 对应你的 AiChatMessageSent 事件
    on<AiChatCleared>(_onChatCleared);
    
    // 如果没有提供chatHistoryId，生成一个固定的默认ID
    if (chatHistoryId == null || chatHistoryId!.isEmpty) {
      chatHistoryId = 'default_chat_${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('AiChatBloc: 未提供chatHistoryId，创建默认ID: $chatHistoryId');
    } else {
      debugPrint('AiChatBloc: 使用提供的chatHistoryId: $chatHistoryId');
    }
  }

  // 系统用户（AI助手）
  final dash.ChatUser _systemUser = dash.ChatUser(
    id: 'ai_assistant',
    firstName: 'AI',
    lastName: '助手',
    profileImage: 'https://storage.googleapis.com/cms-storage-bucket/7a02c344a13b48348940.png'
  );

  void _onInitialized(
    AiChatInitialized event,
    Emitter<AiChatState> emit,
  ) {
    // 初始化但不添加欢迎消息，直接发出一个空消息列表的状态
    debugPrint('AiChatBloc: 初始化');
    emit(state.copyWith(
      messages: [],  // 空消息列表
      isLoading: false,
    ));
  }
  
  void _onInitializedWithHistory(
    AiChatInitializedWithHistory event,
    Emitter<AiChatState> emit,
  ) {
    // 使用提供的历史消息初始化
    if (event.messages.isEmpty) {
      // 如果没有历史消息，则使用空列表初始化，不再添加欢迎消息
      emit(state.copyWith(
        messages: [],
        isLoading: false,
      ));
      debugPrint('AiChatBloc: 使用历史初始化，但历史为空');
      return;
    }
    
    // 使用历史消息初始化状态
    debugPrint('AiChatBloc: 使用历史初始化，消息数: ${event.messages.length}');
    emit(state.copyWith(
      messages: event.messages,
      isLoading: false,
    ));
  }

  Future<void> _onMessageSent(
    AiChatMessageSent event,
    Emitter<AiChatState> emit,
  ) async {
    // 1. 立即显示用户消息
    emit(state.copyWith(
      messages: [...state.messages, event.message],
      isLoading: true,
      clearError: true,
    ));
    
    // 不在这里调用消息添加回调，只在成功获得AI响应后调用
      
    try {
      // 确保聊天ID有值
      final String chatId = chatHistoryId ?? 'default_chat_${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('AiChatBloc: 发送消息，使用聊天ID: $chatId');
      
      // 打印更多调试信息
      debugPrint('AiChatBloc: 用户消息: ${event.message.text}');
      debugPrint('AiChatBloc: 引用数量: ${event.references?.length ?? 0}');
      
      // 2. 调用 Repository 发送网络请求，传递引用对象和聊天ID
      debugPrint('AiChatBloc: 开始调用API...');
      final aiTextResponse = await aiChatRepository.getAiResponse(
        event.message.text,
        references: event.references,
        chatId: chatId, // 传递聊天ID
      );
      
      debugPrint('AiChatBloc: API调用成功，响应长度: ${aiTextResponse.length}');
      
      // 创建AI回复消息
      final aiResponse = dash.ChatMessage(
        user: _systemUser,
        text: aiTextResponse,
        createdAt: DateTime.now(),
      );
      
      // 3. 将真实的 AI 回复添加到聊天记录
      emit(state.copyWith(
        messages: [...state.messages, aiResponse], 
        isLoading: false,
      ));
      
      // 用户消息和AI回复都添加后调用回调，触发保存逻辑
      debugPrint('AiChatBloc: 准备调用消息添加回调...');
      _safeCallMessageAddedCallback();
      debugPrint('AiChatBloc: 消息添加回调调用完成');
    } catch (e) {
      // 4. 如果网络请求失败，显示错误信息
      debugPrint('AiChatBloc: API调用失败: $e');
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
      
      // 请求失败时不保存消息，移除对_safeCallMessageAddedCallback的调用
    }
  }
  
  void _onChatCleared(
    AiChatCleared event,
    Emitter<AiChatState> emit,
  ) {
    // 清除聊天记录
    emit(state.copyWith(messages: []));
    
    // 如果有注册清除回调，则调用
    if (onChatCleared != null) {
      onChatCleared!();
    }
  }
  
  void _safeCallMessageAddedCallback() {
    try {
      if (onMessageAdded != null) {
        onMessageAdded!();
      }
    } catch (e) {
      debugPrint('AiChatBloc: 消息变更回调执行错误: $e');
    }
  }
}