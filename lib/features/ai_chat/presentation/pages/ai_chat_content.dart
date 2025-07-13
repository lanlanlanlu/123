import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:record_app/features/ai_chat/presentation/bloc/ai_chat_bloc.dart';
import 'package:record_app/features/ai_chat/presentation/bloc/ai_chat_event.dart';
import 'package:record_app/data/repository/ai_chat_repository.dart';
import 'package:record_app/features/ai_chat/presentation/pages/ai_chat_page.dart';

/// AI聊天内容
class AiChatContent extends StatelessWidget {
  const AiChatContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        // 在这里提供 AiChatRepository
        RepositoryProvider<AiChatRepository>(
          create: (context) => AiChatRepository(),
        ),
      ],
      child: BlocProvider(
        create: (context) => AiChatBloc(
          // 从上下文中读取并注入 Repository
          aiChatRepository: context.read<AiChatRepository>(),
        )..add(const AiChatInitialized()),
        child: const AiChatPage(),
      ),
    );
  }
}