import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:record_app/features/ai_chat/presentation/bloc/ai_chat_bloc.dart';
import 'package:record_app/features/ai_chat/presentation/bloc/ai_chat_event.dart';
import 'package:record_app/data/repository/ai_chat_repository.dart';
import 'package:record_app/features/ai_chat/presentation/pages/ai_chat_page.dart';
import 'package:record_app/data/repository/chat_history_repository.dart';
import 'package:record_app/data/database/database.dart';

/// AI聊天内容
class AiChatContent extends StatefulWidget {
  const AiChatContent({Key? key}) : super(key: key);

  @override
  State<AiChatContent> createState() => _AiChatContentState();
}

class _AiChatContentState extends State<AiChatContent> {
  // 聊天历史ID
  int? _chatHistoryId;
  
  // 保存定时器，用于防抖
  Timer? _saveTimer;
  
  // 是否正在保存
  bool _isSaving = false;
  
  // AiChatBloc引用
  AiChatBloc? _aiChatBloc;
  
  // ChatHistoryRepository引用
  late final ChatHistoryRepository _chatHistoryRepository;
  
  @override
  void initState() {
    super.initState();
    // 初始化聊天历史仓库
    _chatHistoryRepository = ChatHistoryRepository(context.read<AppDatabase>());
  }
  
  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
  
  // 消息变更回调
  void _onMessageAdded() {
    debugPrint('AiChatContent._onMessageAdded() - 消息添加回调被触发');
    
    // 使用定时器进行防抖，避免频繁保存
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      
      // 检查消息数量和最后一条消息的发送者
      if (_aiChatBloc != null) {
        final messages = _aiChatBloc!.state.messages;
        debugPrint('AiChatContent._onMessageAdded() - 当前消息数: ${messages.length}');
        
        if (messages.isNotEmpty) {
          final lastMessage = messages.last;
          debugPrint('AiChatContent._onMessageAdded() - 最后一条消息发送者: ${lastMessage.user.id}');
        }
      }
      
      _debouncedSaveChat();
    });
  }
  
  /// 防抖保存聊天
  void _debouncedSaveChat() {
    if (_isSaving || _aiChatBloc == null) return; // 如果正在保存，则跳过
    
    // 打印当前消息状态以便调试
    final messages = _aiChatBloc!.state.messages;
    debugPrint('准备保存聊天历史，消息数量：${messages.length}');
    debugPrint('消息发送者列表：${messages.map((m) => m.user.id).toList()}');
    
    // 使用Future延迟执行，避免阻塞UI线程
    Future(() async {
      _isSaving = true;
      try {
        await _saveChat(_aiChatBloc!, _chatHistoryRepository);
      } catch (e) {
        debugPrint('保存聊天历史时出错: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    });
  }
  
  /// 保存当前聊天到历史记录
  Future<void> _saveChat(AiChatBloc aiChatBloc, ChatHistoryRepository chatHistoryRepository) async {
    // 获取当前消息列表
    final messages = aiChatBloc.state.messages;
    
    // 打印详细的消息列表信息用于调试
    debugPrint('AiChatContent._saveChat() - 尝试保存聊天历史，消息总数: ${messages.length}');
    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];
      debugPrint('AiChatContent._saveChat() - 消息[$i]: 发送者=${msg.user.id}, 内容=${msg.text.length > 20 ? '${msg.text.substring(0, 20)}...' : msg.text}');
    }
    
    // 只有当有消息且不是只有欢迎消息时才保存
    if (messages.length <= 1) {
      debugPrint('AiChatContent._saveChat() - 消息数量不足，不保存');
      return;
    }
    
    try {
      // 创建标题 - 使用第一条用户消息作为标题，或第一条消息的前20个字符
      String title = '新对话';
      for (final message in messages) {
        if (message.user.id == 'user_1') {
          title = message.text.length > 20 
              ? '${message.text.substring(0, 20)}...' 
              : message.text;
          break;
        }
      }
      
      // 如果已经保存过，则更新
      if (_chatHistoryId != null) {
        // 获取最新消息
        final lastMessage = messages.last;
        
        // 如果无法获取标题，使用现有标题或默认值
        if (title.trim().isEmpty) {
          try {
            // 尝试获取现有聊天历史的详情
            final historyWithMessages = await chatHistoryRepository.getChatHistoryWithMessages(_chatHistoryId!);
            title = historyWithMessages.chatHistory.title;
          } catch (e) {
            // 如果获取失败，使用默认标题
            title = "对话 $_chatHistoryId";
            debugPrint('AiChatContent._saveChat() - 获取现有标题失败，使用默认标题: $e');
          }
        }
        
        debugPrint('AiChatContent._saveChat() - 更新聊天历史: $_chatHistoryId，最新消息发送者: ${lastMessage.user.id}');
        
        // 更新历史记录
        await chatHistoryRepository.updateChatHistory(
          _chatHistoryId!,
          title.trim().isEmpty ? '新对话' : title, // 确保title不为空
          lastMessage.text,
          messages.length,
        );
        
        // 添加新消息
        await chatHistoryRepository.addMessageToHistory(
          historyId: _chatHistoryId!,
          message: lastMessage,
        );
        debugPrint('AiChatContent._saveChat() - 更新了聊天历史: $_chatHistoryId');
      } else {
        // 创建新的聊天历史
        debugPrint('AiChatContent._saveChat() - 创建新的聊天历史，消息数: ${messages.length}');
        _chatHistoryId = await chatHistoryRepository.saveChat(
          title: title.trim().isEmpty ? '新对话' : title, // 确保title不为空
          messages: messages,
        );
        debugPrint('AiChatContent._saveChat() - 创建了新的聊天历史: $_chatHistoryId');
      }
    } catch (e) {
      debugPrint('AiChatContent._saveChat() - 保存聊天历史失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        // 在这里提供 AiChatRepository
        RepositoryProvider<AiChatRepository>(
          create: (context) => AiChatRepository(),
        ),
        // 确保 ChatHistoryRepository 可用
        RepositoryProvider<ChatHistoryRepository>(
          create: (context) => ChatHistoryRepository(context.read<AppDatabase>()),
        ),
      ],
      child: Builder(
        builder: (context) {
          // 创建AiChatBloc
          final aiChatBloc = AiChatBloc(
            // 从上下文中读取并注入 Repository
            aiChatRepository: context.read<AiChatRepository>(),
            // 添加消息变更回调
            onMessageAdded: _onMessageAdded,
          )..add(const AiChatInitialized());
          
          // 保存引用
          _aiChatBloc = aiChatBloc;
          
          return BlocProvider(
            create: (_) => aiChatBloc,
            child: const AiChatPage(),
          );
        }
      ),
    );
  }
}