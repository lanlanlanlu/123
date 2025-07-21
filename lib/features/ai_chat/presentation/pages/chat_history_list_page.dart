import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:record_app/data/database/database.dart';
import 'package:record_app/data/repository/ai_chat_repository.dart';
import 'package:record_app/data/repository/chat_history_repository.dart';
import 'package:intl/intl.dart';
import 'package:dash_chat_2/dash_chat_2.dart' as dash;
import 'package:record_app/features/ai_chat/presentation/bloc/ai_chat_bloc.dart';
import 'package:record_app/features/ai_chat/presentation/bloc/ai_chat_event.dart';
import 'package:record_app/features/ai_chat/presentation/pages/ai_chat_page.dart';
import 'package:record_app/features/ai_chat/presentation/pages/ai_chat_content.dart';
import 'dart:async'; // Added for Timer

/// 聊天历史列表页面
class ChatHistoryListPage extends StatefulWidget {
  const ChatHistoryListPage({Key? key}) : super(key: key);

  @override
  _ChatHistoryListPageState createState() => _ChatHistoryListPageState();
}

/// 带有历史ID的自定义聊天内容组件
class _CustomAiChatWithHistory extends StatefulWidget {
  final int chatHistoryId;
  final List<dash.ChatMessage> initialMessages;
  final String title;
  
  const _CustomAiChatWithHistory({
    required this.chatHistoryId,
    required this.initialMessages,
    required this.title,
  });
  
  @override
  _CustomAiChatWithHistoryState createState() => _CustomAiChatWithHistoryState();
}

class _CustomAiChatWithHistoryState extends State<_CustomAiChatWithHistory> {
  // 保存定时器，用于防抖
  Timer? _saveTimer;
  
  // 是否正在保存
  bool _isSaving = false;
  
  // AiChatBloc引用
  AiChatBloc? _aiChatBloc;
  
  // 聊天历史ID
  late final int _chatHistoryId;
  
  @override
  void initState() {
    super.initState();
    _chatHistoryId = widget.chatHistoryId;
    debugPrint('ChatHistoryPage: 初始化，使用传入的历史ID：$_chatHistoryId');
  }
  
  @override
  void dispose() {
    _saveTimer?.cancel();
    debugPrint('ChatHistoryPage: dispose 被调用，页面销毁');
    super.dispose();
  }
  
  // 消息变更回调
  void _onMessageAdded() {
    debugPrint('ChatHistoryPage: _onMessageAdded() - 消息添加回调被触发');
    
    // 使用定时器进行防抖，避免频繁保存
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      
      // 检查消息数量和最后一条消息
      if (_aiChatBloc != null) {
        final messages = _aiChatBloc!.state.messages;
        debugPrint('ChatHistoryPage: _onMessageAdded() - 当前消息数: ${messages.length}');
        
        if (messages.isNotEmpty) {
          final lastMessage = messages.last;
          debugPrint('ChatHistoryPage: _onMessageAdded() - 最后一条消息发送者: ${lastMessage.user.id}');
        }
      }
      
      _debouncedSaveChat();
    });
  }
  
  // 聊天清除回调 - 对于聊天历史页面，不重置历史ID，因为是固定的
  void _onChatCleared() {
    debugPrint('ChatHistoryPage: _onChatCleared() - 聊天被清除，但保留历史ID: $_chatHistoryId');
    // 对于历史页面，不需要重置chatHistoryId
  }

  /// 防抖保存聊天
  void _debouncedSaveChat() {
    if (_isSaving || _aiChatBloc == null) return;
    
    // 打印当前消息状态以便调试
    final messages = _aiChatBloc!.state.messages;
    debugPrint('ChatHistoryPage: 准备保存聊天历史，消息数量：${messages.length}');
    
    // 使用Future延迟执行，避免阻塞UI线程
    Future(() async {
      _isSaving = true;
      try {
        await _saveChat(_aiChatBloc!, context.read<ChatHistoryRepository>());
      } catch (e) {
        debugPrint('ChatHistoryPage: 保存聊天历史时出错: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    });
  }
  
  /// 保存聊天内容到历史记录
  Future<void> _saveChat(AiChatBloc aiChatBloc, ChatHistoryRepository chatHistoryRepository) async {
    // 获取当前消息列表
    final messages = aiChatBloc.state.messages;
    
    // 打印详细的消息列表
    debugPrint('ChatHistoryPage: _saveChat() - 尝试保存聊天历史，消息总数: ${messages.length}');
    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];
      debugPrint('ChatHistoryPage: _saveChat() - 消息[$i]: 发送者=${msg.user.id}');
    }
    
    // 如果没有消息或消息数量不足，不保存
    // 至少需要有一对消息：用户问题和AI回复
    if (messages.length < 2) {
      debugPrint('ChatHistoryPage: _saveChat() - 消息数量不足，不保存，需要至少一个用户问题和一个AI回复');
      return;
    }
    
    // 验证消息格式：用户和AI交替出现，最后一条是AI回复
    final lastMessage = messages.last;
    if (lastMessage.user.id != 'ai_assistant') {
      debugPrint('ChatHistoryPage: _saveChat() - 最后一条消息不是AI回复，不保存');
      return;
    }
    
    // 验证倒数第二条消息是用户消息
    final secondLastMessage = messages[messages.length - 2];
    if (secondLastMessage.user.id != 'user_1') {
      debugPrint('ChatHistoryPage: _saveChat() - 倒数第二条消息不是用户消息，消息格式异常，不保存');
      return;
    }
    
    try {
      debugPrint('ChatHistoryPage: _saveChat() - 使用历史ID: $_chatHistoryId');
      
      // 从数据库获取现有消息
      final existingHistory = await chatHistoryRepository.getChatHistoryWithMessages(_chatHistoryId);
      final existingMessages = existingHistory.messages;
      
      debugPrint('ChatHistoryPage: _saveChat() - 现有消息数: ${existingMessages.length}, 当前UI消息数: ${messages.length}');
      
      // 更新历史记录信息
      await chatHistoryRepository.updateChatHistory(
        _chatHistoryId,
        widget.title,  // 使用传入的标题
        lastMessage.text,
        messages.length,
      );
      
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
      
      debugPrint('ChatHistoryPage: _saveChat() - 用户消息已存在: $userMessageExists, AI回复已存在: $aiMessageExists');
      
      // 保存用户消息（如果不存在）
      if (!userMessageExists && messages.length >= 2) {
        final userMsg = messages[messages.length - 2];
        final newSequenceNumber = maxSequenceNumber + 1;
        
        debugPrint('ChatHistoryPage: _saveChat() - 添加用户消息，序列号: $newSequenceNumber');
        await chatHistoryRepository.addMessageToHistory(
          historyId: _chatHistoryId,
          message: userMsg,
          sequenceNumber: newSequenceNumber,
        );
        maxSequenceNumber = newSequenceNumber;
      }
      
      // 保存AI回复（如果不存在）
      if (!aiMessageExists) {
        final aiMsg = messages[messages.length - 1];
        final newSequenceNumber = maxSequenceNumber + 1;
        
        debugPrint('ChatHistoryPage: _saveChat() - 添加AI回复，序列号: $newSequenceNumber');
        await chatHistoryRepository.addMessageToHistory(
          historyId: _chatHistoryId,
          message: aiMsg,
          sequenceNumber: newSequenceNumber,
        );
      }
      
      debugPrint('ChatHistoryPage: _saveChat() - 保存成功');
    } catch (e) {
      debugPrint('ChatHistoryPage: _saveChat() - 保存聊天历史失败: $e');
      throw e; // 重新抛出异常以便外部处理
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AiChatRepository>(
          create: (context) => AiChatRepository(),
        ),
      ],
      child: Builder(
        builder: (context) {
          // 创建AiChatBloc
          final aiChatBloc = AiChatBloc(
            aiChatRepository: context.read<AiChatRepository>(),
            onMessageAdded: _onMessageAdded, // 设置消息变更回调
            onChatCleared: _onChatCleared, // 添加清除回调
          )..add(AiChatInitializedWithHistory(widget.initialMessages));
          
          // 保存引用
          _aiChatBloc = aiChatBloc;
          
          return BlocProvider(
            create: (_) => aiChatBloc,
            child: Scaffold(
              appBar: AppBar(
                title: Text(widget.title),
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              body: const AiChatPage(),
            ),
          );
        }
      ),
    );
  }
}

class _ChatHistoryListPageState extends State<ChatHistoryListPage> {
  late final ChatHistoryRepository _chatHistoryRepository;
  List<ChatHistory> _histories = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _chatHistoryRepository = ChatHistoryRepository(context.read<AppDatabase>());
    _loadHistories();
  }
  
  /// 加载所有聊天历史
  Future<void> _loadHistories() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final histories = await _chatHistoryRepository.getAllChatHistories();
      setState(() {
        _histories = histories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载聊天历史失败: $e')),
      );
    }
  }
  
  /// 删除历史记录
  Future<void> _deleteHistory(ChatHistory history) async {
    try {
      await _chatHistoryRepository.deleteChatHistory(history.id);
      // 刷新列表
      _loadHistories();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除聊天历史')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }
  
  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      // 今天，显示时间
      return '今天 ${DateFormat('HH:mm').format(dateTime)}';
    } else if (difference.inDays == 1) {
      // 昨天
      return '昨天 ${DateFormat('HH:mm').format(dateTime)}';
    } else if (difference.inDays < 7) {
      // 一周内
      return '${difference.inDays}天前';
    } else {
      // 超过一周
      return DateFormat('MM-dd HH:mm').format(dateTime);
    }
  }

  /// 恢复历史聊天记录
  Future<void> _restoreHistoryChat(ChatHistory history, AiChatRepository aiChatRepository) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 获取历史记录详情，包括所有消息
      final historyWithMessages = await _chatHistoryRepository.getChatHistoryWithMessages(history.id);
      
      // 转换数据库消息为dash_chat格式的消息
      final messages = _chatHistoryRepository.convertToMessages(historyWithMessages.messages);
      
      if (messages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法恢复空的聊天历史')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // 获取AppDatabase实例
      final appDatabase = context.read<AppDatabase>();
      
      // 使用pushReplacement替换当前页面
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MultiRepositoryProvider(
            providers: [
              RepositoryProvider<AiChatRepository>.value(value: aiChatRepository),
              RepositoryProvider<ChatHistoryRepository>.value(value: _chatHistoryRepository),
              RepositoryProvider<AppDatabase>.value(value: appDatabase),
            ],
            child: Builder(
              builder: (context) {
                // 创建带有历史ID和消息变更回调的自定义聊天内容
                return _CustomAiChatWithHistory(
                  chatHistoryId: history.id,
                  initialMessages: messages,
                  title: history.title,
                );
              }
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载聊天历史失败: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 获取AiChatRepository实例
    final aiChatRepository = context.read<AiChatRepository>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('聊天历史'),
        centerTitle: true,
        actions: [
          // 刷新按钮
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistories,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : _histories.isEmpty
          ? _buildEmptyView()
          : RefreshIndicator(
              onRefresh: _loadHistories,
              child: ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: _histories.length,
                itemBuilder: (context, index) {
                  final history = _histories[index];
                  return _buildHistoryItem(history, aiChatRepository);
                },
              ),
            ),
    );
  }
  
  /// 构建空视图
  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            '没有聊天历史记录',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '与AI助手的对话将会保存在这里',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('刷新'),
            onPressed: _loadHistories,
          ),
        ],
      ),
    );
  }
  
  /// 构建历史记录项
  Widget _buildHistoryItem(ChatHistory history, AiChatRepository aiChatRepository) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
      child: InkWell(
        onTap: () => _restoreHistoryChat(history, aiChatRepository),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      history.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _formatDateTime(history.updatedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              if (history.lastMessage != null && history.lastMessage!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text(
                    history.lastMessage!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${history.messageCount} 条消息',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    const Spacer(),
                    // 删除按钮
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _showDeleteConfirmation(history),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// 显示删除确认对话框
  void _showDeleteConfirmation(ChatHistory history) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除聊天历史'),
        content: Text('确定要删除"${history.title}"吗？这个操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteHistory(history);
            },
            child: const Text('删除'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
} 