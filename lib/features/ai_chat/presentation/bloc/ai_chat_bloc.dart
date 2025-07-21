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

  AiChatBloc({required this.aiChatRepository, this.onMessageAdded}) : super(const AiChatState()) {
    on<AiChatInitialized>(_onInitialized);
    on<AiChatInitializedWithHistory>(_onInitializedWithHistory); // 处理带历史消息的初始化
    on<AiChatMessageSent>(_onMessageSent); // 对应你的 AiChatMessageSent 事件
    on<AiChatCleared>(_onChatCleared);
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
    // 初始化逻辑保持不变
    final welcomeMessage = dash.ChatMessage(
      user: _systemUser,
      text: '你好！我是你的AI笔记助手。你可以向我询问关于你笔记的任何问题。',
      createdAt: DateTime.now(),
    );
    
    emit(state.copyWith(
      messages: [welcomeMessage],
      isLoading: false,
    ));
  }
  
  void _onInitializedWithHistory(
    AiChatInitializedWithHistory event,
    Emitter<AiChatState> emit,
  ) {
    // 使用提供的历史消息初始化
    if (event.messages.isEmpty) {
      // 如果没有历史消息，则使用默认欢迎消息
      _onInitialized(const AiChatInitialized(), emit);
      return;
    }
    
    // 使用历史消息初始化状态
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
    
    // 不再在这里调用消息添加回调
    // 而是在收到AI回复后一起调用，这样可以一次性保存用户消息和AI回复
      
    try {
      // 2. 调用 Repository 发送网络请求，传递引用对象
      final aiTextResponse = await aiChatRepository.getAiResponse(
        event.message.text,
        references: event.references,
      );
      
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
      _safeCallMessageAddedCallback();
    } catch (e) {
      // 4. 如果网络请求失败，显示错误信息
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
      
      // 即使请求失败，也应该保存用户发送的消息
      _safeCallMessageAddedCallback();
    }
  }

  void _onChatCleared(
    AiChatCleared event,
    Emitter<AiChatState> emit,
  ) {
    // 清除逻辑保持不变
    final welcomeMessage = dash.ChatMessage(
      user: _systemUser,
      text: '聊天记录已清除。有什么我可以帮你的吗？',
      createdAt: DateTime.now(),
    );
    
    emit(state.copyWith(
      messages: [welcomeMessage],
      isLoading: false,
      clearError: true,
    ));
  }
  
  // 安全地调用消息添加回调，不会阻塞主线程
  void _safeCallMessageAddedCallback() {
    if (onMessageAdded == null) return;
    
    // 使用延迟的Future确保回调在消息处理完成后执行
    // 增加延迟时间以确保状态完全更新后再触发回调
    Future.delayed(const Duration(milliseconds: 300), () {
      onMessageAdded?.call();
    });
  }
}