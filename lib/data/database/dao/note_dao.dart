part of '../database.dart';

@DriftAccessor(tables: [Notes, Tags, NoteTags, NoteLocations, NoteImages])
class NoteDao extends DatabaseAccessor<AppDatabase> with _$NoteDaoMixin {
  NoteDao(super.db);

  Stream<List<Note>> watchAllNotes() {
    return (select(notes)
      ..where((tbl) => tbl.isDeleted.equals(false))
      ..orderBy([
            (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)
      ]))
        .watch();
  }

  Future<List<Note>> getAllNotes() {
    return (select(notes)
      ..where((tbl) => tbl.isDeleted.equals(false))
      ..orderBy([
            (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)
      ]))
        .get();
  }

  // 监听单个笔记
  Stream<Note> watchNote(int noteId) {
    return (select(notes)..where((tbl) => tbl.id.equals(noteId)))
        .watchSingle();
  }

  // 根据 noteId 查询其所有的 Tag
  Stream<List<Tag>> watchTagsForNote(int noteId) {
    final query = select(noteTags).join([
      innerJoin(tags, tags.id.equalsExp(noteTags.tagId)),
    ])
      ..where(noteTags.noteId.equals(noteId));

    return query.watch().map((rows) => rows.map((row) => row.readTable(tags)).toList());
  }

  Stream<List<Note>> watchNotesByTagName(String tagName) {
    // 【最终修复】使用集成查询 (Integrated Query)
    final query = select(noteTags).join([
      innerJoin(tags, tags.id.equalsExp(noteTags.tagId)),
      innerJoin(notes, notes.id.equalsExp(noteTags.noteId)),
    ])
      ..where(tags.name.equals(tagName) & notes.isDeleted.equals(false));

    return query.watch().map((rows) {
      // 将查询结果从 Row 类型映射回 Note 对象
      return rows.map((row) => row.readTable(notes)).toList();
    });
  }

  Stream<List<NoteLocation>> watchLocationsForNote(int noteId) {
    return (select(noteLocations)
      ..where((tbl) => tbl.noteId.equals(noteId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<int> insertNote(NotesCompanion note) => into(notes).insert(note);

  Future<bool> updateNote(NotesCompanion note) => update(notes).replace(note);

  Future<int> softDeleteNote(int id) {
    return (update(notes)..where((tbl) => tbl.id.equals(id)))
        .write(const NotesCompanion(isDeleted: Value(true)));
  }

  Future<int> restoreNote(int id) {
    return (update(notes)..where((tbl) => tbl.id.equals(id)))
        .write(const NotesCompanion(isDeleted: Value(false)));
  }

  Future<List<Tag>> getTagsForNote(int noteId) {
    final query = select(noteTags).join([
      innerJoin(tags, tags.id.equalsExp(noteTags.tagId)),
    ])
      ..where(noteTags.noteId.equals(noteId));

    return query.map((row) => row.readTable(tags)).get();
  }


  // 【新增】查询一个笔记的所有图片
  Stream<List<NoteImage>> watchImagesForNote(int noteId) {
    return (select(noteImages)..where((tbl) => tbl.noteId.equals(noteId))).watch();
  }

  Future<List<NoteImage>> getImagesForNote(int noteId) {
    return (select(noteImages)..where((tbl) => tbl.noteId.equals(noteId))).get();
  }

  // 通过ID获取笔记
  Future<Note> getNoteById(int noteId) {
    return (select(notes)..where((tbl) => tbl.id.equals(noteId))).getSingle();
  }

  // 【新增】一个统一的方法来更新一个笔记的所有图片
  Future<void> updateImagesForNote(int noteId, List<String> imagePaths) async {
    // 1. 先删除该笔记所有旧的图片关联
    await (delete(noteImages)..where((tbl) => tbl.noteId.equals(noteId))).go();

    if (imagePaths.isNotEmpty) {
      // 2. 批量插入新的图片关联
      final companions = imagePaths
          .map((path) => NoteImagesCompanion.insert(noteId: noteId, path: path))
          .toList();
      await batch((batch) {
        batch.insertAll(noteImages, companions);
      });
    }
  }

}