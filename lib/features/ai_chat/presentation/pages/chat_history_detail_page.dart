import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:record_app/data/database/database.dart';
import 'package:record_app/data/repository/chat_history_repository.dart';
import 'package:intl/intl.dart';
import 'package:dash_chat_2/dash_chat_2.dart' as dash;
import 'package:record_app/features/ai_chat/presentation/bloc/ai_chat_bloc.dart';
import 'package:record_app/features/ai_chat/presentation/bloc/ai_chat_event.dart';
import 'package:record_app/data/repository/ai_chat_repository.dart';
import 'ai_chat_page.dart';

/// 聊天历史详情页面
class ChatHistoryDetailPage extends StatefulWidget {
  final int historyId;
  
  const ChatHistoryDetailPage({Key? key, required this.historyId}) : super(key: key);

  @override
  _ChatHistoryDetailPageState createState() => _ChatHistoryDetailPageState();
}

class _ChatHistoryDetailPageState extends State<ChatHistoryDetailPage> {
  late final ChatHistoryRepository _chatHistoryRepository;
  ChatHistoryWithMessages? _historyWithMessages;
  bool _isLoading = true;
  String _errorMessage = '';
  
  @override
  void initState() {
    super.initState();
    _chatHistoryRepository = ChatHistoryRepository(context.read<AppDatabase>());
    _loadChatHistory();
  }
  
  /// 加载聊天历史详情
  Future<void> _loadChatHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final historyWithMessages = await _chatHistoryRepository.getChatHistoryWithMessages(widget.historyId);
      setState(() {
        _historyWithMessages = historyWithMessages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '加载聊天历史失败: $e';
        _isLoading = false;
      });
    }
  }
  
  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
  }
  
  /// 继续聊天 - 使用此历史记录创建新的AI聊天会话
  void _continueChat() {
    if (_historyWithMessages == null || _historyWithMessages!.messages.isEmpty) {
      return;
    }
    
    // 转换消息格式
    final dashMessages = _chatHistoryRepository.convertToMessages(_historyWithMessages!.messages);
    
    // 创建一个新的AI聊天页面，并传入历史消息
    final aiChatRepository = context.read<AiChatRepository>();
    
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => BlocProvider(
          create: (context) => AiChatBloc(
            aiChatRepository: aiChatRepository,
          )..add(AiChatInitializedWithHistory(dashMessages)),
          child: const AiChatPage(),
        ),
      ),
      // 保留历史列表页面，但移除当前详情页面
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _historyWithMessages?.chatHistory.title ?? '聊天详情',
          style: const TextStyle(fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          // 继续聊天按钮
          TextButton.icon(
            icon: const Icon(Icons.chat),
            label: const Text('继续聊天'),
            onPressed: !_isLoading && _errorMessage.isEmpty ? _continueChat : null,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : _errorMessage.isNotEmpty
          ? _buildErrorView()
          : _buildChatView(),
    );
  }
  
  /// 构建错误视图
  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            _errorMessage,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadChatHistory,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
  
  /// 构建聊天视图
  Widget _buildChatView() {
    if (_historyWithMessages == null || _historyWithMessages!.messages.isEmpty) {
      return const Center(child: Text('没有聊天消息'));
    }
    
    // 创建用户和AI的ChatUser对象
    final userChatUser = dash.ChatUser(id: 'user_1', firstName: '我');
    final aiChatUser = dash.ChatUser(
      id: 'ai_assistant',
      firstName: 'AI',
      lastName: '助手',
      profileImage: 'https://storage.googleapis.com/cms-storage-bucket/7a02c344a13b48348940.png'
    );
    
    return Column(
      children: [
        // 聊天创建时间
        Container(
          padding: const EdgeInsets.all(8.0),
          color: Colors.grey[100],
          child: Text(
            '创建于 ${_formatDateTime(_historyWithMessages!.chatHistory.createdAt)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ),
        
        // 聊天消息列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: _historyWithMessages!.messages.length,
            itemBuilder: (context, index) {
              final message = _historyWithMessages!.messages[index];
              final isUser = message.sender == 'user_1';
              
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.8,
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: isUser ? Colors.blue[100] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 处理可能存在的@提及项
                      if (message.mentionItems != null && message.mentionItems!.isNotEmpty)
                        _buildMentionItems(message.mentionItems!),
                        
                      // 消息文本
                      Text(
                        message.content,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      
                      // 消息时间
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          DateFormat('HH:mm').format(message.createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  /// 构建@提及项视图
  Widget _buildMentionItems(String mentionItemsJson) {
    try {
      // 尝试解析JSON
      final mentionItems = jsonDecode(mentionItemsJson);
      if (mentionItems == null || mentionItems is! List || mentionItems.isEmpty) {
        return const SizedBox.shrink();
      }
      
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Wrap(
          spacing: 4.0,
          runSpacing: 4.0,
          children: [
            for (final item in mentionItems)
              if (item is Map && item.containsKey('title') && item.containsKey('type'))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  margin: const EdgeInsets.only(right: 4.0, bottom: 4.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withOpacity(0.3), width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _getMentionIcon(item['type'] as int),
                      const SizedBox(width: 4),
                      Text(
                        item['title'] as String,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      );
    } catch (e) {
      // JSON解析错误
      debugPrint('Failed to parse mention items: $e');
      return const SizedBox.shrink();
    }
  }
  
  /// 获取提及项图标
  Widget _getMentionIcon(int typeIndex) {
    IconData iconData;
    switch (typeIndex) {
      case 0: // note
        iconData = Icons.description;
        break;
      case 1: // tag
        iconData = Icons.label;
        break;
      case 2: // location
        iconData = Icons.location_on;
        break;
      default:
        iconData = Icons.help_outline;
    }
    
    return Icon(
      iconData,
      size: 14,
      color: Theme.of(context).primaryColor,
    );
  }
} 