import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:record_app/features/ai_chat/presentation/bloc/ai_chat_bloc.dart';
import 'package:record_app/features/ai_chat/presentation/bloc/ai_chat_event.dart';
import 'package:record_app/data/repository/ai_chat_repository.dart';
import 'package:record_app/features/ai_chat/presentation/widgets/ai_chat_app_bar.dart';
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
  // 聊天历史ID - 主页面初始为null
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
    // 确保主页面初始化时_chatHistoryId为null
    _chatHistoryId = null;
    debugPrint('AiChatContent: 初始化，chatHistoryId = null');
  }
  
  @override
  void dispose() {
    _saveTimer?.cancel();
    // 离开页面时不需要自动保存，已经在消息添加时保存
    debugPrint('AiChatContent: dispose 被调用，页面销毁');
    super.dispose();
  }
  
  // 消息变更回调
  void _onMessageAdded() {
    debugPrint('AiChatContent: _onMessageAdded() - 消息添加回调被触发');
    
    // 使用定时器进行防抖，避免频繁保存
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      
      // 检查消息数量和最后一条消息的发送者
      if (_aiChatBloc != null) {
        final messages = _aiChatBloc!.state.messages;
        debugPrint('AiChatContent: _onMessageAdded() - 当前消息数: ${messages.length}');
        
        if (messages.isNotEmpty) {
          final lastMessage = messages.last;
          debugPrint('AiChatContent: _onMessageAdded() - 最后一条消息发送者: ${lastMessage.user.id}');
        }
      }
      
      _debouncedSaveChat();
    });
  }
  
  // 聊天清除回调
  void _onChatCleared() {
    debugPrint('AiChatContent: _onChatCleared() - 聊天被清除，重置历史ID');
    // 重置聊天历史ID
    setState(() {
      _chatHistoryId = null;
    });
  }
  
  /// 防抖保存聊天
  void _debouncedSaveChat() {
    if (_isSaving || _aiChatBloc == null) return; // 如果正在保存，则跳过
    
    // 打印当前消息状态以便调试
    final messages = _aiChatBloc!.state.messages;
    debugPrint('AiChatContent: 准备保存聊天历史，消息数量：${messages.length}');
    
    // 使用Future延迟执行，避免阻塞UI线程
    Future(() async {
      _isSaving = true;
      try {
        await _saveChat(_aiChatBloc!, _chatHistoryRepository);
      } catch (e) {
        debugPrint('AiChatContent: 保存聊天历史时出错: $e');
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
    debugPrint('AiChatContent: _saveChat() - 尝试保存聊天历史，消息总数: ${messages.length}');
    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];
      debugPrint('AiChatContent: _saveChat() - 消息[$i]: 发送者=${msg.user.id}');
    }
    
    // 如果没有消息或消息数量不足，不保存
    // 至少需要有一对消息：用户问题和AI回复
    if (messages.length < 2) {
      debugPrint('AiChatContent: _saveChat() - 消息数量不足，不保存，需要至少一个用户问题和一个AI回复');
      return;
    }
    
    // 验证消息格式：用户和AI交替出现，最后一条是AI回复
    final lastMessage = messages.last;
    if (lastMessage.user.id != 'ai_assistant') {
      debugPrint('AiChatContent: _saveChat() - 最后一条消息不是AI回复，不保存');
      return;
    }
    
    // 验证倒数第二条消息是用户消息
    final secondLastMessage = messages[messages.length - 2];
    if (secondLastMessage.user.id != 'user_1') {
      debugPrint('AiChatContent: _saveChat() - 倒数第二条消息不是用户消息，消息格式异常，不保存');
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
      
      // 确保title不为空
      if (title.trim().isEmpty) {
        title = '新对话';
      }
      
      debugPrint('AiChatContent: _saveChat() - 当前chatHistoryId: $_chatHistoryId');
      
      // 如果已经保存过，则更新
      if (_chatHistoryId != null) {
        debugPrint('AiChatContent: _saveChat() - 更新现有聊天历史: $_chatHistoryId');
        
        // 更新历史记录
        await chatHistoryRepository.updateChatHistory(
          _chatHistoryId!,
          title,
          lastMessage.text,
          messages.length,
        );
        
        // 获取该历史记录已有的消息
        final existingHistory = await chatHistoryRepository.getChatHistoryWithMessages(_chatHistoryId!);
        final existingMessages = existingHistory.messages;
        
        // 检查最后两条消息是否已存在
        bool userMessageExists = false;
        bool aiMessageExists = false;
        int maxSequenceNumber = 0;
        
        for (final existingMsg in existingMessages) {
          // 找出最大序列号
          if (existingMsg.sequenceNumber > maxSequenceNumber) {
            maxSequenceNumber = existingMsg.sequenceNumber;
          }
          
          // 检查用户消息和AI回复是否已存在
          if (messages.length >= 2) {
            final userMsg = messages[messages.length - 2]; // 用户消息
            final aiMsg = messages[messages.length - 1];   // AI回复
            
            if (existingMsg.content == userMsg.text && 
                existingMsg.sender == userMsg.user.id) {
              userMessageExists = true;
            }
            
            if (existingMsg.content == aiMsg.text && 
                existingMsg.sender == aiMsg.user.id) {
              aiMessageExists = true;
            }
          }
        }
        
        debugPrint('AiChatContent: _saveChat() - 用户消息已存在: $userMessageExists, AI回复已存在: $aiMessageExists');
        
        // 保存用户消息（如果不存在）
        if (!userMessageExists && messages.length >= 2) {
          final userMsg = messages[messages.length - 2];
          final newSequenceNumber = maxSequenceNumber + 1;
          
          debugPrint('AiChatContent: _saveChat() - 添加用户消息，序列号: $newSequenceNumber');
          await chatHistoryRepository.addMessageToHistory(
            historyId: _chatHistoryId!,
            message: userMsg,
            sequenceNumber: newSequenceNumber,
          );
          maxSequenceNumber = newSequenceNumber;
        }
        
        // 保存AI回复（如果不存在）
        if (!aiMessageExists) {
          final aiMsg = messages[messages.length - 1];
          final newSequenceNumber = maxSequenceNumber + 1;
          
          debugPrint('AiChatContent: _saveChat() - 添加AI回复，序列号: $newSequenceNumber');
          await chatHistoryRepository.addMessageToHistory(
            historyId: _chatHistoryId!,
            message: aiMsg,
            sequenceNumber: newSequenceNumber,
          );
        }
        
        debugPrint('AiChatContent: _saveChat() - 更新完成');
      } else {
        // 创建新的聊天历史
        debugPrint('AiChatContent: _saveChat() - 创建新的聊天历史，消息数: ${messages.length}');
        final historyId = await chatHistoryRepository.saveChat(
          title: title,
          messages: messages,
        );
        
        // 保存ID并且不要重新初始化AiChatBloc
        setState(() {
          _chatHistoryId = historyId;
        });
        
        debugPrint('AiChatContent: _saveChat() - 创建了新的聊天历史: $_chatHistoryId，保持当前消息状态');
      }
    } catch (e) {
      debugPrint('AiChatContent: _saveChat() - 保存聊天历史失败: $e');
      throw e; // 重新抛出异常以便外部处理
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<AiChatRepository>(
      create: (context) => AiChatRepository(),
      child: BlocProvider<AiChatBloc>(
        create: (context) {
          final bloc = AiChatBloc(
            aiChatRepository: context.read<AiChatRepository>(),
            onMessageAdded: _onMessageAdded,
            onChatCleared: _onChatCleared,
            chatHistoryId: _chatHistoryId?.toString(),
          );
          _aiChatBloc = bloc; // 存储引用
          return bloc;
        },
        child: Builder(
          builder: (context) {
            return Scaffold(
              // 移除AppBar，避免重复
              body: const AiChatPage(),
            );
          },
        ),
      ),
    );
  }
}