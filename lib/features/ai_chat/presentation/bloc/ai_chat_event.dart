import 'package:equatable/equatable.dart';
import 'package:dash_chat_2/dash_chat_2.dart' as dash;
import 'package:record_app/data/models/chat_reference.dart';

abstract class AiChatEvent extends Equatable {
  const AiChatEvent();

  @override
  List<Object?> get props => [];
}

class AiChatInitialized extends AiChatEvent {
  const AiChatInitialized();
}

/// 使用历史消息初始化AI聊天
class AiChatInitializedWithHistory extends AiChatEvent {
  final List<dash.ChatMessage> messages;
  
  const AiChatInitializedWithHistory(this.messages);
  
  @override
  List<Object?> get props => [messages];
}

class AiChatMessageSent extends AiChatEvent {
  final dash.ChatMessage message;
  final List<ChatReference> references;
  
  const AiChatMessageSent(this.message, {this.references = const []});
  
  @override
  List<Object?> get props => [message, references];
}

class AiChatCleared extends AiChatEvent {
  const AiChatCleared();
} 