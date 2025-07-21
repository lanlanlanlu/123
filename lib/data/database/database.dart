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

// 【新增】用于存储聊天历史会话
@DataClassName('ChatHistory')
class ChatHistories extends Table {
  IntColumn get id => integer().autoIncrement()();
  // 会话标题
  TextColumn get title => text().withLength(max: 255)();
  // 最后一条消息预览
  TextColumn get lastMessage => text().withLength(max: 255).nullable()();
  // 消息数量
  IntColumn get messageCount => integer().withDefault(const Constant(0))();
  // 创建和更新时间
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();
}

// 【新增】用于存储聊天消息
@DataClassName('ChatMessage')
class ChatMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  // 关联到哪个聊天历史
  IntColumn get chatHistoryId => integer().references(ChatHistories, #id)();
  // 消息内容
  TextColumn get content => text()();
  // 发送者 (user 或 ai)
  TextColumn get sender => text()();
  // 消息中包含的@提及项JSON格式
  TextColumn get mentionItems => text().nullable()();
  // 消息在对话中的序列号
  IntColumn get sequenceNumber => integer()();
  // 创建时间
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
}

// --- 数据类 ---
class NoteWithTags {
  final Note note;
  final List<Tag> tags;
  NoteWithTags({required this.note, required this.tags});
}

// 【新增】聊天历史记录与消息的关联数据类
class ChatHistoryWithMessages {
  final ChatHistory chatHistory;
  final List<ChatMessage> messages;
  ChatHistoryWithMessages({required this.chatHistory, required this.messages});
}

// --- 数据库主类 ---
@DriftDatabase(
    tables: [
      Notes, 
      Tags, 
      NoteTags, 
      NoteLocations, 
      NoteImages, 
      RecentMentions,
      ChatHistories, // 【新增】聊天历史表
      ChatMessages, // 【新增】聊天消息表
    ], 
    daos: [NoteDao, TagDao]
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  // 【修改】schemaVersion 从 10 变为 11，添加聊天历史相关表
  @override
  int get schemaVersion => 11;

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
        // 【新增】从版本 10 升级到 11 的逻辑：添加聊天历史和消息表
        if (from < 11) {
          await m.createTable(chatHistories);
          await m.createTable(chatMessages);
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

  // 【新增】获取所有聊天历史
  Future<List<ChatHistory>> getAllChatHistories() {
    return (select(chatHistories)
      ..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)]))
      .get();
  }
  
  // 【新增】通过ID获取聊天历史
  Future<ChatHistory> getChatHistoryById(int id) {
    return (select(chatHistories)..where((t) => t.id.equals(id))).getSingle();
  }
  
  // 【新增】获取聊天历史的所有消息
  Future<List<ChatMessage>> getChatMessagesByHistoryId(int historyId) {
    return (select(chatMessages)
      ..where((t) => t.chatHistoryId.equals(historyId))
      ..orderBy([(t) => OrderingTerm(expression: t.sequenceNumber)]))
      .get();
  }
  
  // 【新增】创建新的聊天历史
  Future<int> createChatHistory(ChatHistoriesCompanion history) {
    return into(chatHistories).insert(history);
  }
  
  // 【新增】添加聊天消息
  Future<int> addChatMessage(ChatMessagesCompanion message) {
    return into(chatMessages).insert(message);
  }
  
  // 【新增】更新聊天历史
  Future<bool> updateChatHistory(ChatHistoriesCompanion history) {
    return update(chatHistories).replace(history);
  }
  
  // 【新增】获取聊天历史及其所有消息
  Future<ChatHistoryWithMessages> getChatHistoryWithMessages(int historyId) async {
    final history = await getChatHistoryById(historyId);
    final messages = await getChatMessagesByHistoryId(historyId);
    return ChatHistoryWithMessages(chatHistory: history, messages: messages);
  }
}