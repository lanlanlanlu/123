part of '../database.dart';

@DriftAccessor(tables: [Tags, NoteTags, Notes])
class TagDao extends DatabaseAccessor<AppDatabase> with _$TagDaoMixin {
  TagDao(super.db);

  Stream<List<Tag>> watchAllTags() {
    return (select(tags)..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();
  }

  // 【新增】获取最近使用的5个标签
  Stream<List<Tag>> watchRecentTags() {
    final query = select(tags).join([
      innerJoin(noteTags, noteTags.tagId.equalsExp(tags.id)),
      innerJoin(notes, notes.id.equalsExp(noteTags.noteId)),
    ])
    // 按笔记的更新时间倒序排列，最新的在最前面
      ..orderBy([OrderingTerm.desc(notes.updatedAt)]);

    return query.watch().map((rows) {
      final recentTags = rows.map((row) => row.readTable(tags)).toList();
      // 使用 Map 来确保标签的唯一性（因为一个标签可能在多个近期笔记中出现）
      // 并保留其第一次出现的顺序（即最新的顺序）
      final uniqueTags = Map.fromEntries(recentTags.map((tag) => MapEntry(tag.id, tag))).values.toList();
      // 最后只返回前5个
      return uniqueTags.take(5).toList();
    });
  }
}