import 'package:drift/drift.dart';
import 'package:record/data/database/database.dart';

/// 笔记数据仓库，封装所有与笔记相关的数据操作
class NotesRepository {
  final AppDatabase _database;

  NotesRepository(this._database);

  /// 监听所有笔记
  Stream<List<Note>> watchAllNotes() {
    return _database.noteDao.watchAllNotes();
  }

  /// 监听单个笔记
  Stream<Note> watchNote(int noteId) {
    return _database.noteDao.watchNote(noteId);
  }

  /// 监听特定笔记的标签
  Stream<List<Tag>> watchTagsForNote(int noteId) {
    return _database.noteDao.watchTagsForNote(noteId);
  }

  /// 监听指定标签名称的所有笔记
  Stream<List<Note>> watchNotesByTagName(String tagName) {
    return _database.noteDao.watchNotesByTagName(tagName);
  }

  /// 监听特定笔记的位置信息
  Stream<List<NoteLocation>> watchLocationsForNote(int noteId) {
    return _database.noteDao.watchLocationsForNote(noteId);
  }

  /// 监听特定笔记的图片
  Stream<List<NoteImage>> watchImagesForNote(int noteId) {
    return _database.noteDao.watchImagesForNote(noteId);
  }

  /// 获取特定笔记的图片
  Future<List<NoteImage>> getImagesForNote(int noteId) {
    return _database.noteDao.getImagesForNote(noteId);
  }

  /// 获取特定笔记的标签
  Future<List<Tag>> getTagsForNote(int noteId) {
    return _database.noteDao.getTagsForNote(noteId);
  }

  /// 插入一条新笔记
  Future<int> insertNote(NotesCompanion note) {
    return _database.noteDao.insertNote(note);
  }

  /// 更新笔记
  Future<bool> updateNote(NotesCompanion note) {
    return _database.noteDao.updateNote(note);
  }

  /// 软删除笔记
  Future<int> softDeleteNote(int id) {
    return _database.noteDao.softDeleteNote(id);
  }

  /// 恢复已删除的笔记
  Future<int> restoreNote(int id) {
    return _database.noteDao.restoreNote(id);
  }

  /// 更新笔记的图片
  Future<void> updateImagesForNote(int noteId, List<String> imagePaths) {
    return _database.noteDao.updateImagesForNote(noteId, imagePaths);
  }

  /// 保存笔记（创建新笔记或更新现有笔记）
  Future<int> saveNoteEntry(Note? existingNote, String rawText, {List<String>? imagePaths}) async {
    if (rawText.trim().isEmpty && (imagePaths == null || imagePaths.isEmpty)) {
      if (existingNote != null) {
        await _database.noteDao.softDeleteNote(existingNote.id);
      }
      return existingNote?.id ?? -1;
    }

    final tagRegExp = RegExp(r"#([\p{L}\p{N}_]+)", unicode: true);
    final locationRegExp = RegExp(r"@([\p{L}\p{N}_]+)", unicode: true);

    final tagNames = tagRegExp.allMatches(rawText).map((match) => match.group(1)!).toSet();
    final locations = locationRegExp.allMatches(rawText).map((match) => match.group(1)!).toList();

    String? locationToSave;
    if (locations.isNotEmpty) {
      locationToSave = locations.last;
    } else if (existingNote != null) {
      locationToSave = existingNote.locationInfo;
    }

    String contentToSave = rawText.replaceAll(tagRegExp, '').replaceAll(locationRegExp, '').trim();
    final title = contentToSave.isNotEmpty ? contentToSave.split('\n').first : '';

    final now = DateTime.now();

    return await _database.transaction(() async {
      int noteId;
      Set<String> finalTagNames = tagNames;

      if (existingNote != null) {
        noteId = existingNote.id;
        final oldTags = await (_database.select(_database.noteTags)..where((t) => t.noteId.equals(noteId)))
            .join([innerJoin(_database.tags, _database.tags.id.equalsExp(_database.noteTags.tagId))])
            .get();
        final oldTagNames = oldTags.map((row) => row.readTable(_database.tags).name).toSet();
        finalTagNames.addAll(oldTagNames);
        final companion = NotesCompanion(
          id: Value(noteId),
          title: Value(title),
          content: Value(contentToSave),
          locationInfo: Value(locationToSave),
          updatedAt: Value(now),
        );
        await (_database.update(_database.notes)..where((t) => t.id.equals(noteId))).write(companion);
      } else {
        final companion = NotesCompanion(
          title: Value(title),
          content: Value(contentToSave),
          locationInfo: Value(locationToSave),
          createdAt: Value(now),
          updatedAt: Value(now),
        );
        noteId = await _database.into(_database.notes).insert(companion);
      }

      if (locationToSave != null && locationToSave.isNotEmpty) {
        await _database.into(_database.noteLocations).insert(
          NoteLocationsCompanion.insert(
            noteId: noteId,
            location: locationToSave,
            createdAt: Value(now),
          ),
          onConflict: DoNothing(target: [_database.noteLocations.location, _database.noteLocations.noteId]),
        );
      }

      if (imagePaths != null) {
        await _database.noteDao.updateImagesForNote(noteId, imagePaths);
      }

      await (_database.delete(_database.noteTags)..where((tbl) => tbl.noteId.equals(noteId))).go();
      for (final name in finalTagNames) {
        final tagId = await _database.into(_database.tags).insert(
          TagsCompanion.insert(name: name),
          onConflict: DoNothing(target: [_database.tags.name]),
        );
        final finalTagId = tagId > 0 ? tagId : await (_database.select(_database.tags)..where((t) => t.name.equals(name))).getSingle().then((t) => t.id);
        await _database.into(_database.noteTags).insert(NoteTagsCompanion.insert(noteId: noteId, tagId: finalTagId));
      }

      return noteId;
    });
  }

  /// 为笔记添加标签
  Future<void> addTagToNote(int noteId, String tagName) async {
    await _database.into(_database.tags).insert(
      TagsCompanion.insert(name: tagName),
      onConflict: DoNothing(target: [_database.tags.name]),
    );
    
    final tag = await (_database.select(_database.tags)..where((t) => t.name.equals(tagName))).getSingle();
    
    await _database.into(_database.noteTags).insert(
      NoteTagsCompanion.insert(noteId: noteId, tagId: tag.id),
      onConflict: DoNothing(target: [_database.noteTags.noteId, _database.noteTags.tagId]),
    );
  }

  /// 为笔记添加位置
  Future<void> addLocationToNote(int noteId, String location, DateTime createdAt) async {
    await _database.into(_database.noteLocations).insert(
      NoteLocationsCompanion.insert(
        noteId: noteId,
        location: location,
        createdAt: Value(createdAt),
      ),
      onConflict: DoNothing(target: [_database.noteLocations.location, _database.noteLocations.noteId]),
    );
  }

  /// 解析文本中的标签
  Set<String> parseTagsFromText(String text) {
    final tagRegExp = RegExp(r"#([\p{L}\p{N}_]+)", unicode: true);
    return tagRegExp.allMatches(text).map((match) => match.group(1)!).toSet();
  }

  /// 解析文本中的位置
  List<String> parseLocationsFromText(String text) {
    final locationRegExp = RegExp(r"@([\p{L}\p{N}_]+)", unicode: true);
    return locationRegExp.allMatches(text).map((match) => match.group(1)!).toList();
  }

  /// 清理文本，移除标签和位置标记
  String cleanText(String text) {
    final tagRegExp = RegExp(r"#([\p{L}\p{N}_]+)", unicode: true);
    final locationRegExp = RegExp(r"@([\p{L}\p{N}_]+)", unicode: true);
    return text.replaceAll(tagRegExp, '').replaceAll(locationRegExp, '').trim();
  }

  /// 通过ID获取笔记
  Future<Note> getNoteById(int noteId) {
    return _database.noteDao.getNoteById(noteId);
  }
} 