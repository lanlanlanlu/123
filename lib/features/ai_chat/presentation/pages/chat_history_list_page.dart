import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:record_app/data/database/database.dart';
import 'package:record_app/data/repository/chat_history_repository.dart';
import 'package:intl/intl.dart';
import 'chat_history_detail_page.dart';

/// 聊天历史列表页面
class ChatHistoryListPage extends StatefulWidget {
  const ChatHistoryListPage({Key? key}) : super(key: key);

  @override
  _ChatHistoryListPageState createState() => _ChatHistoryListPageState();
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

  @override
  Widget build(BuildContext context) {
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
                  return _buildHistoryItem(history);
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
  Widget _buildHistoryItem(ChatHistory history) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
      child: InkWell(
        onTap: () {
          // 导航到聊天历史详情页面
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChatHistoryDetailPage(historyId: history.id),
            ),
          ).then((_) => _loadHistories()); // 返回时刷新列表
        },
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