import 'package:equatable/equatable.dart';
import 'package:dash_chat_2/dash_chat_2.dart' as dash;

class AiChatState extends Equatable {
  final List<dash.ChatMessage> messages;
  final bool isLoading;
  final String? error;
  
  const AiChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });
  
  AiChatState copyWith({
    List<dash.ChatMessage>? messages,
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