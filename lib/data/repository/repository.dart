import 'package:record_app/data/database/database.dart';
import 'package:record_app/data/repository/notes_repository.dart';
import 'package:record_app/data/repository/tags_repository.dart';

/// 中央仓库管理类，统一管理所有数据仓库
class Repository {
  final NotesRepository notesRepository;
  final TagsRepository tagsRepository;

  Repository._({
    required this.notesRepository,
    required this.tagsRepository,
  });

  /// 工厂构造函数，从数据库实例创建仓库
  factory Repository.fromDatabase(AppDatabase database) {
    return Repository._(
      notesRepository: NotesRepository(database),
      tagsRepository: TagsRepository(database),
    );
  }
  
  /// 工厂构造函数，从已存在的仓库实例创建
  factory Repository.fromRepositories({
    required NotesRepository notesRepository,
    required TagsRepository tagsRepository,
  }) {
    return Repository._(
      notesRepository: notesRepository,
      tagsRepository: tagsRepository,
    );
  }
  
  /// 获取所有笔记
  Future<List<Note>> getAllNotes() {
    return notesRepository.getAllNotes();
  }
} 