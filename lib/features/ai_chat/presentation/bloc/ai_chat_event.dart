import 'package:equatable/equatable.dart';
import 'package:dash_chat_2/dash_chat_2.dart';

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