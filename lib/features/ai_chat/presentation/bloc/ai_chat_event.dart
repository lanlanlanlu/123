import 'package:equatable/equatable.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:record_app/data/models/chat_reference.dart';

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
  final List<ChatReference> references;
  
  const AiChatMessageSent(this.message, {this.references = const []});
  
  @override
  List<Object?> get props => [message, references];
}

class AiChatCleared extends AiChatEvent {
  const AiChatCleared();
} 