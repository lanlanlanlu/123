import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:record_app/features/ai_chat/presentation/bloc/ai_chat_bloc.dart';
import 'ai_chat_page.dart';

/// AI聊天内容
class AiChatContent extends StatelessWidget {
  const AiChatContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AiChatBloc()..add(const AiChatInitialized()),
      child: const AiChatPage(),
    );
  }
} 