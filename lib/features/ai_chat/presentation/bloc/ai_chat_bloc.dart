import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dash_chat_2/dash_chat_2.dart';

// 事件部分
abstract class AiChatEvent extends Equatable {
  const AiChatEvent();

  @override
  List<Object?> get props => [];
}

class AiChatInitialized extends AiChatEvent {
  const AiChatInitialized();
}

class AiChatMessageSent extends AiChatEvent {
  final ChatMessage message;
  
  const AiChatMessageSent(this.message);
  
  @override
  List<Object?> get props => [message];
}

class AiChatCleared extends AiChatEvent {
  const AiChatCleared();
}

// 状态部分
class AiChatState extends Equatable {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;
  
  const AiChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });
  
  AiChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
  
  @override
  List<Object?> get props => [messages, isLoading, error];
}

// Bloc部分
class AiChatBloc extends Bloc<AiChatEvent, AiChatState> {
  AiChatBloc() : super(const AiChatState()) {
    on<AiChatInitialized>(_onInitialized);
    on<AiChatMessageSent>(_onMessageSent);
    on<AiChatCleared>(_onChatCleared);
  }

  // 系统用户（AI助手）
  final ChatUser _systemUser = ChatUser(
    id: 'ai_assistant',
    firstName: 'AI',
    lastName: '助手',
  );

  void _onInitialized(
    AiChatInitialized event,
    Emitter<AiChatState> emit,
  ) {
    // 初始化聊天，加载欢迎消息
    final welcomeMessage = ChatMessage(
      user: _systemUser,
      text: '你好！我是你的AI笔记助手。你可以和我聊天，或者使用@tag来访问特定标签的笔记内容。',
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
    try {
      // 添加用户消息到聊天记录
      final updatedMessages = [...state.messages, event.message];
      emit(state.copyWith(
        messages: updatedMessages,
        isLoading: true,
        clearError: true,
      ));
      
      // 这里处理AI回复
      // 实际应用中，这里需要调用AI服务API
      await Future.delayed(const Duration(seconds: 1));
      
      // 处理@标签
      final messageText = event.message.text;
      String responseText = '';
      
      if (messageText.contains('@')) {
        // 提取标签
        final tagMatch = RegExp(r'@(\w+)').firstMatch(messageText);
        if (tagMatch != null) {
          final tag = tagMatch.group(1);
          responseText = '我注意到你提到了标签 #$tag，我会为你查找相关的笔记内容。';
          // 这里实际需要查询数据库获取相关笔记
        } else {
          responseText = '我看到你使用了@符号，但没有指定有效的标签。请使用"@标签名"格式来查询特定标签的内容。';
        }
      } else {
        responseText = '我收到了你的消息: "${messageText}"。目前我还在学习中，稍后会有更智能的回复。';
      }
      
      final aiResponse = ChatMessage(
        user: _systemUser,
        text: responseText,
        createdAt: DateTime.now(),
      );
      
      final newMessages = [...updatedMessages, aiResponse];
      emit(state.copyWith(
        messages: newMessages,
        isLoading: false,
      ));
    } catch (e) {
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
    // 清除聊天记录，但保留欢迎消息
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