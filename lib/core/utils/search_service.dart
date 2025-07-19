import 'dart:convert';
import 'package:record_app/data/database/database.dart';
import 'package:record_app/data/repository/notes_repository.dart';
import 'package:record_app/data/database/connection/connection.dart' as connection;

/// 搜索类型枚举
enum SearchType {
  all,    // 所有类型
  note,   // 笔记
  tag,    // 标签
  location // 地点
}

/// 搜索结果项
class SearchResultItem {
  final String id;
  final String title;
  final SearchType type;
  final String? subtitle;

  const SearchResultItem({
    required this.id,
    required this.title,
    required this.type,
    this.subtitle,
  });
}

/// 通用搜索服务
class SearchService {
  final AppDatabase _database;
  final NotesRepository _notesRepository;
  
  // 构造函数，允许依赖注入以便于测试
  SearchService({AppDatabase? database, NotesRepository? notesRepository}) 
    : _database = database ?? connection.connect(),
      _notesRepository = notesRepository ?? NotesRepository();
  
  /// 从Quill JSON内容中提取纯文本
  String _extractPlainTextFromQuill(String content) {
    if (content.isEmpty) return '';
    
    try {
      // 尝试解析JSON
      final List<dynamic> jsonContent = json.decode(content);
      
      // 提取所有insert字段的内容并连接
      final StringBuffer plainText = StringBuffer();
      
      for (final item in jsonContent) {
        if (item is Map<String, dynamic> && item.containsKey('insert')) {
          final insert = item['insert'];
          if (insert is String) {
            plainText.write(insert);
          }
        }
      }
      
      final result = plainText.toString().trim();
      
      // 提取第一句话或有限字符
      final firstSentence = _extractFirstSentence(result);
      return firstSentence;
    } catch (e) {
      // 如果解析失败，返回原始内容的一部分
      return content.length > 50 ? '${content.substring(0, 50)}...' : content;
    }
  }
  
  /// 提取文本中的第一句话，或者前30个字符
  String _extractFirstSentence(String text) {
    if (text.isEmpty) return '';
    
    // 寻找句号、问号、感叹号作为句子结束标志
    final endOfSentence = text.indexOf(RegExp(r'[.!?。！？]'));
    
    if (endOfSentence > 0 && endOfSentence < 50) {
      // 找到句子结尾且长度合理
      return '${text.substring(0, endOfSentence + 1)}';
    } else if (text.length <= 30) {
      // 文本很短，直接返回
      return text;
    } else {
      // 截取前30个字符
      return '${text.substring(0, 30)}...';
    }
  }
  
  /// 搜索笔记
  Future<List<SearchResultItem>> searchNotes(String query) async {
    if (query.isEmpty) {
      return [];
    }
    
    // 获取所有笔记并过滤
    final notes = await _notesRepository.getAllNotes();
    
    // 简单字符串匹配，将来可改进为更高级的搜索算法
    final filteredNotes = notes.where((note) => 
      note.title.toLowerCase().contains(query.toLowerCase()) || 
      (note.content.toLowerCase().contains(query.toLowerCase()))
    ).toList();
    
    // 转换为SearchResultItem，提取Quill内容中的纯文本作为预览
    return filteredNotes.map((note) => SearchResultItem(
      id: note.id.toString(),
      title: note.title,
      type: SearchType.note,
      subtitle: _extractPlainTextFromQuill(note.content),
    )).toList();
  }
  
  /// 搜索标签
  Future<List<SearchResultItem>> searchTags(String query) async {
    if (query.isEmpty) {
      return [];
    }
    
    // 获取所有标签
    final tags = await _database.tagDao.watchAllTags().first;
    
    // 过滤标签
    final filteredTags = tags.where((tag) => 
      tag.name.toLowerCase().contains(query.toLowerCase())
    ).toList();
    
    // 转换为SearchResultItem
    return filteredTags.map((tag) => SearchResultItem(
      id: tag.name,
      title: tag.name,
      type: SearchType.tag,
    )).toList();
  }
  
  /// 搜索地点
  Future<List<SearchResultItem>> searchLocations(String query) async {
    if (query.isEmpty) {
      return [];
    }
    
    // 获取所有地点
    final locations = await _notesRepository.getAllLocations();
    
    // 过滤地点
    final filteredLocations = locations.where((location) => 
      location.toLowerCase().contains(query.toLowerCase())
    ).toList();
    
    // 转换为SearchResultItem
    return filteredLocations.map((location) => SearchResultItem(
      id: location,
      title: location,
      type: SearchType.location,
    )).toList();
  }
  
  /// 搜索所有内容
  Future<List<SearchResultItem>> searchAll(String query) async {
    if (query.isEmpty) {
      return [];
    }
    
    // 并行执行所有搜索以提高性能
    final results = await Future.wait([
      searchNotes(query),
      searchTags(query),
      searchLocations(query),
    ]);
    
    // 合并结果
    final List<SearchResultItem> allResults = [
      ...results[0], // 笔记
      ...results[1], // 标签
      ...results[2], // 地点
    ];
    
    return allResults;
  }
} 