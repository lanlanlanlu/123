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
    
    // 转换为SearchResultItem
    return filteredNotes.map((note) => SearchResultItem(
      id: note.id.toString(),
      title: note.title,
      type: SearchType.note,
      subtitle: note.content.length > 50 ? '${note.content.substring(0, 50)}...' : note.content,
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