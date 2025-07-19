import 'package:drift/drift.dart';
import 'package:record_app/data/database/database.dart';
import 'package:record_app/data/database/connection/connection.dart' as connection;
import 'package:flutter/foundation.dart';

/// 用于处理最近@提及的项目的存储库
class RecentMentionsRepository {
  final AppDatabase _database;

  RecentMentionsRepository([AppDatabase? database]) : _database = database ?? connection.connect();

  /// 添加一条最近提及记录
  Future<int> addRecentMention({
    required String type,
    required String itemId,
    required String title,
  }) async {
    try {
      final mention = RecentMentionsCompanion(
        type: Value(type),
        itemId: Value(itemId),
        title: Value(title),
        usedAt: Value(DateTime.now()),
      );
      
      return await _database.addRecentMention(mention);
    } catch (e) {
      debugPrint('Error adding recent mention: $e');
      return -1; // 返回-1表示添加失败
    }
  }
  
  /// 记录笔记提及
  Future<int> addNoteMention(Note note) async {
    try {
      return await addRecentMention(
        type: 'note',
        itemId: note.id.toString(),
        title: note.title,
      );
    } catch (e) {
      debugPrint('Error adding note mention: $e');
      return -1;
    }
  }
  
  /// 记录标签提及
  Future<int> addTagMention(String tagName) async {
    try {
      return await addRecentMention(
        type: 'tag',
        itemId: tagName,
        title: tagName,
      );
    } catch (e) {
      debugPrint('Error adding tag mention: $e');
      return -1;
    }
  }
  
  /// 记录地点提及
  Future<int> addLocationMention(String location) async {
    try {
      return await addRecentMention(
        type: 'location',
        itemId: location,
        title: location,
      );
    } catch (e) {
      debugPrint('Error adding location mention: $e');
      return -1;
    }
  }
  
  /// 获取最近提及记录
  Future<List<RecentMention>> getRecentMentions({int limit = 2}) async {
    try {
      return await _database.getRecentMentions(limit: limit);
    } catch (e) {
      debugPrint('Error getting recent mentions: $e');
      return []; // 出错时返回空列表
    }
  }
  
  /// 获取特定类型的最近提及记录
  Future<List<RecentMention>> getRecentMentionsByType(String type, {int limit = 2}) async {
    try {
      return await _database.getRecentMentionsByType(type, limit: limit);
    } catch (e) {
      debugPrint('Error getting recent mentions by type: $e');
      return []; // 出错时返回空列表
    }
  }
} 