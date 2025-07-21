import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:dash_chat_2/dash_chat_2.dart' as dash;
import 'package:record_app/data/database/database.dart';
import 'package:record_app/data/models/chat_reference.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// 聊天历史存储库
class ChatHistoryRepository {
  final AppDatabase _database;
  
  ChatHistoryRepository(this._database);
  
  /// 获取所有聊天历史
  Future<List<ChatHistory>> getAllChatHistories() {
    return _database.getAllChatHistories();
  }
  
  /// 根据ID获取聊天历史及其消息
  Future<ChatHistoryWithMessages> getChatHistoryWithMessages(int historyId) {
    return _database.getChatHistoryWithMessages(historyId);
  }
  
  /// 创建新的聊天历史
  Future<int> createChatHistory(String title) {
    return _database.createChatHistory(
      ChatHistoriesCompanion.insert(
        title: title,
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
  
  /// 更新现有的聊天历史
  Future<bool> updateChatHistory(
    int historyId, 
    String title, 
    String lastMessage, 
    int messageCount,
  ) {
    // 确保title不为空
    if (title.isEmpty) {
      title = '新对话';
    }
    
    return _database.updateChatHistory(
      ChatHistoriesCompanion(
        id: Value(historyId),
        title: Value(title), // 确保title始终有值
        lastMessage: Value(lastMessage.length > 50 
            ? '${lastMessage.substring(0, 47)}...' 
            : lastMessage),
        messageCount: Value(messageCount),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
  
  /// 保存完整的聊天会话（用于创建新的聊天会话）
  Future<int> saveChat({
    required String title, 
    required List<dash.ChatMessage> messages,
  }) async {
    // 确保title不为空
    if (title.isEmpty) {
      title = '新对话';
    }
    
    // 打印要保存的消息详情
    debugPrint('准备保存聊天历史，标题: $title，消息数量: ${messages.length}');
    for (int i = 0; i < messages.length; i++) {
      final message = messages[i];
      debugPrint('消息[$i]: 发送者=${message.user.id}, 时间=${message.createdAt}, 内容预览=${message.text.length > 20 ? '${message.text.substring(0, 20)}...' : message.text}');
    }
    
    // 使用事务来确保数据完整性和性能
    return await _database.transaction(() async {
      try {
        // 1. 创建聊天历史记录
        final historyId = await _database.createChatHistory(
          ChatHistoriesCompanion.insert(
            title: title, // 确保title有值
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
        
        if (messages.isEmpty) {
          return historyId;
        }
        
        // 2. 准备批量插入消息
        final companions = <ChatMessagesCompanion>[];
        for (var i = 0; i < messages.length; i++) {
          final message = messages[i];
          
          // 将@提及项转换为JSON字符串
          String? mentionItemsJson;
          if (message.customProperties != null && 
              message.customProperties!.containsKey('mentionItems')) {
            mentionItemsJson = jsonEncode(message.customProperties!['mentionItems']);
          }
          
          debugPrint('准备插入消息 #$i: 发送者=${message.user.id}');
          
          companions.add(
            ChatMessagesCompanion.insert(
              chatHistoryId: historyId,
              content: message.text,
              sender: message.user.id,
              mentionItems: Value(mentionItemsJson),
              sequenceNumber: i,
              createdAt: Value(message.createdAt),
            ),
          );
        }
        
        // 3. 批量插入消息以提高性能
        await _database.batch((batch) {
          batch.insertAll(_database.chatMessages, companions);
        });
        
        // 4. 更新历史记录的最后一条消息预览和消息计数
        final lastMessage = messages.last;
        await _database.updateChatHistory(
          ChatHistoriesCompanion(
            id: Value(historyId),
            title: Value(title), // 确保title值不会丢失
            lastMessage: Value(lastMessage.text.length > 50 
                ? '${lastMessage.text.substring(0, 47)}...' 
                : lastMessage.text),
            messageCount: Value(messages.length),
            updatedAt: Value(DateTime.now()),
          ),
        );
        
        debugPrint('成功保存了聊天历史，ID: $historyId，消息数: ${messages.length}');
        return historyId;
      } catch (e) {
        debugPrint('保存聊天出错: $e');
        rethrow;
      }
    });
  }
  
  /// 添加消息到现有会话
  Future<void> addMessageToHistory({
    required int historyId,
    required dash.ChatMessage message,
  }) async {
    await _database.transaction(() async {
      try {
        // 1. 获取当前消息序列号和历史记录
        final messages = await _database.getChatMessagesByHistoryId(historyId);
        final historyWithMessages = await _database.getChatHistoryWithMessages(historyId);
        final existingTitle = historyWithMessages.chatHistory.title;
        final sequenceNumber = messages.isNotEmpty 
            ? messages.last.sequenceNumber + 1 
            : 0;
        
        // 2. 添加消息
        // 将@提及项转换为JSON字符串
        String? mentionItemsJson;
        if (message.customProperties != null && 
            message.customProperties!.containsKey('mentionItems')) {
          mentionItemsJson = jsonEncode(message.customProperties!['mentionItems']);
        }
        
        // 打印日志，帮助调试
        debugPrint('添加消息到聊天历史，发送者: ${message.user.id}, 内容: ${message.text.length > 30 ? '${message.text.substring(0, 30)}...' : message.text}');
        
        await _database.addChatMessage(
          ChatMessagesCompanion.insert(
            chatHistoryId: historyId,
            content: message.text,
            sender: message.user.id,
            mentionItems: Value(mentionItemsJson),
            sequenceNumber: sequenceNumber,
            createdAt: Value(message.createdAt),
          ),
        );
        
        // 3. 更新历史记录，确保包含title字段
        await _database.updateChatHistory(
          ChatHistoriesCompanion(
            id: Value(historyId),
            title: Value(existingTitle.isEmpty ? '新对话' : existingTitle), // 使用从数据库获取的现有标题，确保不为空
            lastMessage: Value(message.text.length > 50 
                ? '${message.text.substring(0, 47)}...' 
                : message.text),
            messageCount: Value(messages.length + 1),
            updatedAt: Value(DateTime.now()),
          ),
        );
        
        debugPrint('成功添加了消息到聊天历史: $historyId');
      } catch (e) {
        debugPrint('添加消息出错: $e');
        rethrow;
      }
    });
  }
  
  /// 从数据库记录转换为聊天消息对象（用于dash_chat）
  List<dash.ChatMessage> convertToMessages(List<ChatMessage> dbMessages) {
    // 创建用户和AI的ChatUser对象
    final userChatUser = dash.ChatUser(id: 'user_1', firstName: '我');
    final aiChatUser = dash.ChatUser(
      id: 'ai_assistant',
      firstName: 'AI',
      lastName: '助手',
      profileImage: 'https://storage.googleapis.com/cms-storage-bucket/7a02c344a13b48348940.png'
    );
    
    // 转换数据库消息为dash_chat消息
    return dbMessages.map((dbMessage) {
      // 确定发送者
      final isUser = dbMessage.sender == 'user_1';
      final user = isUser ? userChatUser : aiChatUser;
      
      // 解析@提及项
      Map<String, dynamic>? customProperties;
      if (dbMessage.mentionItems != null) {
        try {
          final mentionItems = jsonDecode(dbMessage.mentionItems!);
          customProperties = {'mentionItems': mentionItems};
        } catch (e) {
          // JSON解析错误，忽略提及项
          debugPrint('Failed to parse mention items: $e');
        }
      }
      
      return dash.ChatMessage(
        text: dbMessage.content,
        user: user,
        createdAt: dbMessage.createdAt,
        customProperties: customProperties,
      );
    }).toList();
  }
  
  /// 删除聊天历史记录
  Future<void> deleteChatHistory(int historyId) async {
    return await _database.transaction(() async {
      try {
        // 首先删除与此历史记录相关的所有消息
        await _database.customStatement(
          'DELETE FROM chat_messages WHERE chat_history_id = ?',
          [historyId],
        );
        
        // 然后删除历史记录本身
        await _database.customStatement(
          'DELETE FROM chat_histories WHERE id = ?',
          [historyId],
        );
        
        debugPrint('删除了聊天历史: $historyId');
      } catch (e) {
        debugPrint('删除聊天历史出错: $e');
        rethrow;
      }
    });
  }
} 