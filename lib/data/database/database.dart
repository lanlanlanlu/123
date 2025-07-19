import 'package:drift/drift.dart';

part 'dao/note_dao.dart';
part 'dao/tag_dao.dart';
part 'database.g.dart';

// --- 表定义 ---
@DataClassName('Note')
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(max: 255)();
  TextColumn get content => text()();
  TextColumn get locationInfo => text().nullable()();
  IntColumn get color => integer().nullable()();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  // 是否处于小图模式
  BoolColumn get thumbnailMode => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();
}

@DataClassName('Tag')
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  @override
  List<Set<Column>> get uniqueKeys => [ {name} ];
}

@DataClassName('NoteLocation')
class NoteLocations extends Table {
  IntColumn get noteId => integer().references(Notes, #id)();
  TextColumn get location => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {noteId, location};
}

class NoteTags extends Table {
  IntColumn get noteId => integer().references(Notes, #id)();
  IntColumn get tagId => integer().references(Tags, #id)();
  @override
  Set<Column> get primaryKey => {noteId, tagId};
}

// 【新增】用于存储笔记图片关联的表
@DataClassName('NoteImage')
class NoteImages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get noteId => integer().references(Notes, #id)();
  TextColumn get path => text()(); // 存储图片的本地文件路径
}

// 【新增】用于存储最近@提及的项目
@DataClassName('RecentMention')
class RecentMentions extends Table {
  IntColumn get id => integer().autoIncrement()();
  // 提及类型: 'note', 'tag', 'location'
  TextColumn get type => text()();
  // 提及内容ID: 笔记ID、标签名称、地点名称
  TextColumn get itemId => text()();
  // 提及内容标题: 用于显示
  TextColumn get title => text()();
  // 使用时间
  DateTimeColumn get usedAt => dateTime().clientDefault(() => DateTime.now())();
  
  @override
  List<Set<Column>> get uniqueKeys => [{type, itemId}];
}

// --- 数据类 ---
class NoteWithTags {
  final Note note;
  final List<Tag> tags;
  NoteWithTags({required this.note, required this.tags});
}

// --- 数据库主类 ---
@DriftDatabase(
    tables: [Notes, Tags, NoteTags, NoteLocations, NoteImages, RecentMentions], // 【修改】加入新表
    daos: [NoteDao, TagDao]
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  // 【修改】schemaVersion 从 9 变为 10
  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.addColumn(notes, notes.locationInfo);
        }
        if (from < 3) {
          await m.createTable(noteLocations);
        }
        if (from < 4) {
          await m.drop(noteLocations);
          await m.createTable(noteLocations);
        }
        // 【修改】从版本 4 升级到 5 的逻辑
        if (from < 5) {
          await m.createTable(noteImages);
        }
        // 【新增】从版本 5 升级到 6 的逻辑
        if (from < 6) {
          // 为现有的笔记添加默认的创建和更新时间
          await customStatement('UPDATE notes SET created_at = CURRENT_TIMESTAMP WHERE created_at IS NULL');
          await customStatement('UPDATE notes SET updated_at = CURRENT_TIMESTAMP WHERE updated_at IS NULL');
        }
        // 【新增】从版本 7 升级到 8 的逻辑：给 notes 加 thumbnail_mode 字段
        if (from < 8) {
          await m.addColumn(notes, notes.thumbnailMode as GeneratedColumn<Object>);
        }
        // 【新增】从版本 8 升级到 9 的逻辑：添加最近提及表
        if (from < 9) {
          await m.createTable(recentMentions);
        }
        // 【新增】从版本 9 升级到 10 的逻辑：重建最近提及表以添加唯一约束
        if (from < 10) {
          // 删除旧表并重新创建
          await m.drop(recentMentions);
          await m.createTable(recentMentions);
        }
      },
    );
  }

  // 添加最近提及记录
  Future<int> addRecentMention(RecentMentionsCompanion mention) {
    return into(recentMentions).insert(
      mention,
      onConflict: DoUpdate((old) => mention.copyWith(usedAt: mention.usedAt), target: [recentMentions.type, recentMentions.itemId]),
    );
  }

  // 获取最近提及记录
  Future<List<RecentMention>> getRecentMentions({int limit = 2}) {
    return (select(recentMentions)
      ..orderBy([(t) => OrderingTerm(expression: t.usedAt, mode: OrderingMode.desc)])
      ..limit(limit))
      .get();
  }

  // 根据类型获取最近提及记录
  Future<List<RecentMention>> getRecentMentionsByType(String type, {int limit = 2}) {
    return (select(recentMentions)
      ..where((t) => t.type.equals(type))
      ..orderBy([(t) => OrderingTerm(expression: t.usedAt, mode: OrderingMode.desc)])
      ..limit(limit))
      .get();
  }
}