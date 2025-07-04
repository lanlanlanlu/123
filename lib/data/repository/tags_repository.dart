import 'package:drift/drift.dart';
import 'package:record/data/database/database.dart';

/// 标签数据仓库，封装所有与标签相关的数据操作
class TagsRepository {
  final AppDatabase _database;

  TagsRepository(this._database);

  /// 监听所有标签
  Stream<List<Tag>> watchAllTags() {
    return _database.tagDao.watchAllTags();
  }

  /// 监听最近使用的标签
  Stream<List<Tag>> watchRecentTags() {
    return _database.tagDao.watchRecentTags();
  }
  
  /// 监听特定笔记的标签
  Stream<List<Tag>> watchTagsForNote(int noteId) {
    return _database.noteDao.watchTagsForNote(noteId);
  }
  
  /// 获取特定笔记的标签
  Future<List<Tag>> getTagsForNote(int noteId) {
    return _database.noteDao.getTagsForNote(noteId);
  }
  
  /// 获取所有标签的年份信息
  Future<Set<String>> getTagYears() async {
    // 执行自定义查询，获取所有与标签关联的笔记的年份
    final query = _database.customSelect(
      '''
      SELECT DISTINCT strftime('%Y', notes.updated_at) as year
      FROM notes
      JOIN note_tags ON notes.id = note_tags.note_id
      WHERE notes.is_deleted = 0
      ORDER BY year DESC
      ''',
    );
    
    final result = await query.get();
    final Set<String> years = {};
    
    // 安全地处理每一行，避免null值
    for (var row in result) {
      final year = row.read<String?>('year');
      if (year != null) {
        years.add(year);
      }
    }
    
    // 确保当前年份总是存在
    final currentYear = DateTime.now().year.toString();
    years.add(currentYear);
    
    return years;
  }
  
  /// 添加标签到笔记
  Future<void> addTagToNote(int noteId, String tagName) async {
    return _database.transaction(() async {
      // 先确保标签存在，如果不存在就创建
      final tagId = await _database.into(_database.tags).insert(
        TagsCompanion.insert(name: tagName),
        onConflict: DoNothing(target: [_database.tags.name]),
      );
      
      // 获取标签ID（如果是新创建的，则使用返回的ID；否则，查询现有的）
      final finalTagId = tagId > 0 ? tagId : 
        await (_database.select(_database.tags)..where((t) => t.name.equals(tagName)))
          .getSingle()
          .then((t) => t.id);
      
      // 添加标签关联
      await _database.into(_database.noteTags).insert(
        NoteTagsCompanion.insert(noteId: noteId, tagId: finalTagId),
        onConflict: DoNothing(target: [_database.noteTags.noteId, _database.noteTags.tagId]),
      );
    });
  }
  
  /// 从笔记中删除标签
  Future<void> removeTagFromNote(int noteId, int tagId) async {
    await (_database.delete(_database.noteTags)
      ..where((t) => t.noteId.equals(noteId) & t.tagId.equals(tagId)))
      .go();
  }
  
  /// 删除标签（从所有笔记中移除该标签的关联）
  Future<void> deleteTag(String tagName) async {
    try {
      // 使用单独的事务处理每个步骤，避免长时间锁定数据库
      // 1. 获取标签ID
      final tag = await (_database.select(_database.tags)
        ..where((t) => t.name.equals(tagName)))
        .getSingleOrNull();
      
      if (tag == null) {
        return; // 标签不存在，无需删除
      }
      
      // 2. 删除所有笔记与该标签的关联
      await (_database.delete(_database.noteTags)
        ..where((nt) => nt.tagId.equals(tag.id)))
        .go();
      
      // 3. 删除标签本身
      await (_database.delete(_database.tags)
        ..where((t) => t.id.equals(tag.id)))
        .go();
      
    } catch (e) {
      throw Exception('删除标签失败: $e');
    }
  }
} 