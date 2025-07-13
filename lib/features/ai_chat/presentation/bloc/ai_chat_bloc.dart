import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dash_chat_2/dash_chat_2.dart';

import 'package:record_app/data/repository/ai_chat_repository.dart'; // 引入 Repository
import 'ai_chat_event.dart';
import 'ai_chat_state.dart';

class AiChatBloc extends Bloc<AiChatEvent, AiChatState> {
  // 添加一个 Repository 依赖
  final AiChatRepository aiChatRepository;

  AiChatBloc({required this.aiChatRepository}) : super(const AiChatState()) {
    on<AiChatInitialized>(_onInitialized);
    on<AiChatMessageSent>(_onMessageSent); // 对应你的 AiChatMessageSent 事件
    on<AiChatCleared>(_onChatCleared);
  }

  // 系统用户（AI助手）
  final ChatUser _systemUser = ChatUser(
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
    final welcomeMessage = ChatMessage(
      user: _systemUser,
      text: '你好！我是你的AI笔记助手。你可以向我询问关于你笔记的任何问题。',
      createdAt: DateTime.now(),
    );
    
    emit(state.copyWith(
      messages: [welcomeMessage],
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
      
    try {
      // 2. 调用 Repository 发送网络请求
      final aiTextResponse = await aiChatRepository.getAiResponse(event.message.text);
      
      final aiResponse = ChatMessage(
        user: _systemUser,
        text: aiTextResponse,
        createdAt: DateTime.now(),
      );
      
      // 3. 将真实的 AI 回复添加到聊天记录
      emit(state.copyWith(
        messages: [...state.messages, aiResponse], 
        isLoading: false,
      ));
    } catch (e) {
      // 4. 如果网络请求失败，显示错误信息
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  void _onChatCleared(
    AiChatCleared event,
    Emitter<AiChatState> emit,
  ) {
    // 清除逻辑保持不变
    final welcomeMessage = ChatMessage(
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
}