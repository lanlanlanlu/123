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
} 