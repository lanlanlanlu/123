import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:record_app/data/database/database.dart';
import 'package:record_app/data/repository/notes_repository.dart';
import 'package:record_app/data/repository/tags_repository.dart';
import 'package:record_app/data/repository/chat_history_repository.dart';
import 'package:record_app/data/database/connection/connection.dart' as connection;
import 'package:drift/drift.dart';
import 'dart:async'; // 添加Timer支持

/// 同步服务 - 负责在本地数据库和Firebase之间同步数据
class SyncService {
  final FirebaseFirestore _firestore;
  final NotesRepository _notesRepository;
  final TagsRepository _tagsRepository;
  final ChatHistoryRepository _chatHistoryRepository;
  final AppDatabase _database;
  final Logger _logger = Logger();
  Timer? _syncTimer; // 添加定时器变量

  SyncService({
    FirebaseFirestore? firestore,
    NotesRepository? notesRepository,
    TagsRepository? tagsRepository,
    ChatHistoryRepository? chatHistoryRepository,
    AppDatabase? database,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _notesRepository = notesRepository ?? NotesRepository(),
       _tagsRepository = tagsRepository ?? TagsRepository(),
       _chatHistoryRepository = chatHistoryRepository ?? ChatHistoryRepository(),
       _database = database ?? connection.connect();

  /// 启动周期性同步
  void startPeriodicSync({Duration interval = const Duration(minutes: 5)}) {
    // 如果已经有定时器在运行，先取消
    _syncTimer?.cancel();
    
    // 创建一个新的定时器
    _syncTimer = Timer.periodic(interval, (timer) {
      _logger.d('开始执行周期性后台同步...');
      performFullSync().catchError((e) {
        _logger.e('周期性同步失败: $e');
      });
    });
    
    _logger.d('已启动周期性同步，间隔: ${interval.inMinutes} 分钟');
  }

  /// 停止周期性同步
  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _logger.d('已停止周期性同步');
  }

  /// 执行全面同步 - 推送本地更改到云端并获取云端更新
  Future<void> performFullSync() async {
    try {
      await Future.wait([
        pushPendingNotes(),
        pushDirtyNotes(),
        pushDeletedNotes(),
        pushPendingTags(),
        pushDirtyTags(),
        pushPendingChatHistories(),
        pushDirtyChatHistories(),
        pushPendingChatMessages(),
        pushDirtyChatMessages(),
      ]);
      
      // 完成后启动监听云端变化
      startListeningForRemoteChanges();
    } catch (e) {
      _logger.e('Full sync failed: $e');
      rethrow;
    }
  }

  // --- 核心同步方法：笔记 ---

  /// 将本地待上传的笔记推送到云端
  Future<void> pushPendingNotes() async {
    try {
      // 从数据库中查询所有待上传(pending)的笔记
      final allPendingNotes = await _database.getNotesForSync();
      final pendingNotes = allPendingNotes.where((note) => note.syncStatus == 'pending').toList();
          
      _logger.d('Found ${pendingNotes.length} pending notes to upload');
      
      // 遍历并上传每条笔记
      for (final note in pendingNotes) {
        // 将Drift Note转换为Firestore文档格式
        final noteData = {
          'title': note.title,
          'content': note.content,
          'locationInfo': note.locationInfo,
          'color': note.color,
          'isPinned': note.isPinned,
          'isArchived': note.isArchived,
          'isDeleted': note.isDeleted,
          'thumbnailMode': note.thumbnailMode,
          'createdAt': Timestamp.fromDate(note.createdAt),
          'updatedAt': Timestamp.fromDate(note.updatedAt),
          'localId': note.id,  // 存储本地ID以便关联
        };
        
        // 添加到Firestore
        final docRef = await _firestore.collection('notes').add(noteData);
        
        // 更新本地记录状态
        await _database.updateSyncStatus(
          note.id, 
          'notes', 
          'synced',
          docRef.id
        );
        
        _logger.d('Uploaded note ${note.id} to Firestore, got ID: ${docRef.id}');
      }
    } catch (e) {
      _logger.e('Error uploading pending notes: $e');
      rethrow;
    }
  }

  /// 将本地已修改的笔记更新到云端
  Future<void> pushDirtyNotes() async {
    try {
      // 从数据库中查询所有已修改(dirty)的笔记
      final allDirtyNotes = await _database.getNotesForSync();
      final dirtyNotes = allDirtyNotes.where((note) => 
          note.syncStatus == 'dirty' && note.firestoreId != null).toList();
          
      _logger.d('Found ${dirtyNotes.length} dirty notes to update');
      
      // 遍历并更新每条笔记
      for (final note in dirtyNotes) {
        if (note.firestoreId == null) continue; // 安全检查
        
        // 将Drift Note转换为Firestore文档格式
        final noteData = {
          'title': note.title,
          'content': note.content,
          'locationInfo': note.locationInfo,
          'color': note.color,
          'isPinned': note.isPinned,
          'isArchived': note.isArchived,
          'isDeleted': note.isDeleted,
          'thumbnailMode': note.thumbnailMode,
          'updatedAt': Timestamp.fromDate(note.updatedAt),
        };
        
        // 更新Firestore文档
        await _firestore.collection('notes').doc(note.firestoreId).update(noteData);
        
        // 更新本地记录状态
        await _database.updateSyncStatus(
          note.id, 
          'notes', 
          'synced',
          note.firestoreId
        );
        
        _logger.d('Updated note ${note.id} in Firestore (doc ID: ${note.firestoreId})');
      }
    } catch (e) {
      _logger.e('Error updating dirty notes: $e');
      rethrow;
    }
  }
  
  /// 处理标记为删除的笔记
  Future<void> pushDeletedNotes() async {
    try {
      // 从数据库中查询所有待删除的笔记
      final allNotesToDelete = await _database.getNotesForSync();
      final notesToDelete = allNotesToDelete.where((note) => 
          note.syncStatus == 'pendingDelete' && note.firestoreId != null).toList();
          
      _logger.d('Found ${notesToDelete.length} notes to delete remotely');
      
      // 遍历并删除每条笔记
      for (final note in notesToDelete) {
        if (note.firestoreId == null) continue; // 安全检查
        
        // 从Firestore中删除
        await _firestore.collection('notes').doc(note.firestoreId).delete();
        
        // 更新本地记录状态或完全删除
        await _database.noteDao.softDeleteNote(note.id);
        
        _logger.d('Deleted note ${note.id} from Firestore (doc ID: ${note.firestoreId})');
      }
    } catch (e) {
      _logger.e('Error deleting notes from cloud: $e');
      rethrow;
    }
  }
  
  // --- 标签同步方法 ---
  
  /// 将本地待上传的标签推送到云端
  Future<void> pushPendingTags() async {
    try {
      // 从数据库中查询所有待上传的标签
      final allPendingTags = await _database.getTagsForSync();
      final pendingTags = allPendingTags.where((tag) => tag.syncStatus == 'pending').toList();
          
      _logger.d('Found ${pendingTags.length} pending tags to upload');
      
      // 遍历并上传每个标签
      for (final tag in pendingTags) {
        // 转换为Firestore文档格式
        final tagData = {
          'name': tag.name,
          'updatedAt': Timestamp.fromDate(tag.updatedAt),
          'localId': tag.id,
        };
        
        // 添加到Firestore
        final docRef = await _firestore.collection('tags').add(tagData);
        
        // 更新本地记录状态
        await _database.updateSyncStatus(
          tag.id, 
          'tags', 
          'synced',
          docRef.id
        );
      }
    } catch (e) {
      _logger.e('Error uploading pending tags: $e');
      rethrow;
    }
  }

  /// 将本地已修改的标签更新到云端
  Future<void> pushDirtyTags() async {
    try {
      // 从数据库中查询所有已修改的标签
      final allDirtyTags = await _database.getTagsForSync();
      final dirtyTags = allDirtyTags.where((tag) => 
          tag.syncStatus == 'dirty' && tag.firestoreId != null).toList();
          
      _logger.d('Found ${dirtyTags.length} dirty tags to update');
      
      // 遍历并更新每个标签
      for (final tag in dirtyTags) {
        if (tag.firestoreId == null) continue; // 安全检查
        
        // 转换为Firestore文档格式
        final tagData = {
          'name': tag.name,
          'updatedAt': Timestamp.fromDate(tag.updatedAt),
        };
        
        // 更新Firestore文档
        await _firestore.collection('tags').doc(tag.firestoreId).update(tagData);
        
        // 更新本地记录状态
        await _database.updateSyncStatus(
          tag.id, 
          'tags', 
          'synced',
          tag.firestoreId
        );
      }
    } catch (e) {
      _logger.e('Error updating dirty tags: $e');
      rethrow;
    }
  }
  
  // --- 聊天历史同步方法 ---
  
  /// 将本地待上传的聊天历史推送到云端
  Future<void> pushPendingChatHistories() async {
    try {
      // 实现同步逻辑...
      final allPendingHistories = await _database.getChatHistoriesForSync();
      final pendingHistories = allPendingHistories.where((history) => 
          history.syncStatus == 'pending').toList();
          
      for (final history in pendingHistories) {
        final historyData = {
          'title': history.title,
          'lastMessage': history.lastMessage,
          'messageCount': history.messageCount,
          'createdAt': Timestamp.fromDate(history.createdAt),
          'updatedAt': Timestamp.fromDate(history.updatedAt),
          'localId': history.id,
        };
        
        final docRef = await _firestore.collection('chatHistories').add(historyData);
        await _database.updateSyncStatus(
          history.id, 
          'chat_histories', 
          'synced',
          docRef.id
        );
      }
    } catch (e) {
      _logger.e('Error uploading pending chat histories: $e');
      rethrow;
    }
  }

  /// 将本地已修改的聊天历史更新到云端
  Future<void> pushDirtyChatHistories() async {
    try {
      // 实现同步逻辑...
      final allDirtyHistories = await _database.getChatHistoriesForSync();
      final dirtyHistories = allDirtyHistories.where((history) => 
          history.syncStatus == 'dirty' && history.firestoreId != null).toList();
          
      for (final history in dirtyHistories) {
        if (history.firestoreId == null) continue;
        
        final historyData = {
          'title': history.title,
          'lastMessage': history.lastMessage,
          'messageCount': history.messageCount,
          'updatedAt': Timestamp.fromDate(history.updatedAt),
        };
        
        await _firestore.collection('chatHistories').doc(history.firestoreId).update(historyData);
        await _database.updateSyncStatus(
          history.id, 
          'chat_histories', 
          'synced',
          history.firestoreId
        );
      }
    } catch (e) {
      _logger.e('Error updating dirty chat histories: $e');
      rethrow;
    }
  }
  
  // --- 聊天消息同步方法 ---
  
  /// 将本地待上传的聊天消息推送到云端
  Future<void> pushPendingChatMessages() async {
    try {
      // 实现同步逻辑...
      final allPendingMessages = await _database.getChatMessagesForSync();
      final pendingMessages = allPendingMessages.where((message) => 
          message.syncStatus == 'pending').toList();
          
      for (final message in pendingMessages) {
        // 获取关联的聊天历史的firestore ID
        final chatHistory = await _database.getChatHistoryById(message.chatHistoryId);
        if (chatHistory.firestoreId == null) {
          _logger.w('Cannot upload message: parent chat history not synced yet');
          continue;
        }
        
        final messageData = {
          'content': message.content,
          'sender': message.sender,
          'mentionItems': message.mentionItems,
          'sequenceNumber': message.sequenceNumber,
          'createdAt': Timestamp.fromDate(message.createdAt),
          'updatedAt': Timestamp.fromDate(message.updatedAt),
          'chatHistoryId': chatHistory.firestoreId, // 使用父记录的Firestore ID
          'localId': message.id,
          'localChatHistoryId': message.chatHistoryId,
        };
        
        final docRef = await _firestore.collection('chatMessages').add(messageData);
        await _database.updateSyncStatus(
          message.id, 
          'chat_messages', 
          'synced',
          docRef.id
        );
      }
    } catch (e) {
      _logger.e('Error uploading pending chat messages: $e');
      rethrow;
    }
  }

  /// 将本地已修改的聊天消息更新到云端
  Future<void> pushDirtyChatMessages() async {
    try {
      // 实现同步逻辑...
      final allDirtyMessages = await _database.getChatMessagesForSync();
      final dirtyMessages = allDirtyMessages.where((message) => 
          message.syncStatus == 'dirty' && message.firestoreId != null).toList();
          
      for (final message in dirtyMessages) {
        if (message.firestoreId == null) continue;
        
        final messageData = {
          'content': message.content,
          'sender': message.sender,
          'mentionItems': message.mentionItems,
          'updatedAt': Timestamp.fromDate(message.updatedAt),
        };
        
        await _firestore.collection('chatMessages').doc(message.firestoreId).update(messageData);
        await _database.updateSyncStatus(
          message.id, 
          'chat_messages', 
          'synced',
          message.firestoreId
        );
      }
    } catch (e) {
      _logger.e('Error updating dirty chat messages: $e');
      rethrow;
    }
  }

  // --- 云端数据监听与拉取 ---

  /// 启动监听远程数据变化的流程
  void startListeningForRemoteChanges() {
    if (kIsWeb) {
      _logger.d('Starting remote change listeners (web)');
    } else {
      _logger.d('Starting remote change listeners (native)');
    }
    
    // 监听笔记变化
    _listenForNoteChanges();
    
    // 监听标签变化
    _listenForTagChanges();
    
    // 监听聊天历史变化
    _listenForChatHistoryChanges();
    
    // 监听聊天消息变化
    _listenForChatMessageChanges();
  }
  
  /// 监听笔记集合的变化
  void _listenForNoteChanges() {
    _firestore.collection('notes').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        _handleNoteChange(change);
      }
    }, onError: (e) {
      _logger.e('Error listening for note changes: $e');
    });
  }
  
  /// 处理笔记变更
  Future<void> _handleNoteChange(DocumentChange<Map<String, dynamic>> change) async {
    try {
      final noteData = change.doc.data();
      if (noteData == null) return;
      
      final firestoreId = change.doc.id;
      final remoteUpdatedAt = (noteData['updatedAt'] as Timestamp?)?.toDate();
      final localId = noteData['localId'] as int?;

      // 根据变更类型处理
      switch (change.type) {
        case DocumentChangeType.added:
          await _handleRemoteNoteAdded(firestoreId, noteData);
          break;
        
        case DocumentChangeType.modified:
          await _handleRemoteNoteModified(firestoreId, noteData, remoteUpdatedAt, localId);
          break;
        
        case DocumentChangeType.removed:
          await _handleRemoteNoteRemoved(firestoreId);
          break;
      }
    } catch (e) {
      _logger.e('Error handling note change: $e');
    }
  }
  
  /// 处理云端新增笔记
  Future<void> _handleRemoteNoteAdded(String firestoreId, Map<String, dynamic> noteData) async {
    // 1. 检查此笔记是否已存在于本地
    final localNotes = await _database.noteDao.getAllNotes();
    final existingNote = localNotes.where((note) => note.firestoreId == firestoreId).firstOrNull;
    
    if (existingNote != null) {
      // 已存在，无需处理
      return;
    }
    
    // 2. 如果本地不存在，创建新笔记
    final createdAt = (noteData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final updatedAt = (noteData['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    
    final newNote = NotesCompanion.insert(
      title: noteData['title'] as String? ?? 'Untitled',
      content: noteData['content'] as String? ?? '',
      locationInfo: Value(noteData['locationInfo'] as String?),
      color: Value(noteData['color'] as int?),
      isPinned: Value(noteData['isPinned'] as bool? ?? false),
      isArchived: Value(noteData['isArchived'] as bool? ?? false),
      isDeleted: Value(noteData['isDeleted'] as bool? ?? false),
      thumbnailMode: Value(noteData['thumbnailMode'] as bool? ?? false),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      firestoreId: Value(firestoreId),
      syncStatus: const Value('synced'),
    );
    
    await _database.noteDao.insertNote(newNote);
    _logger.d('Added note from cloud, Firestore ID: $firestoreId');
  }
  
  /// 处理云端修改笔记
  Future<void> _handleRemoteNoteModified(
    String firestoreId, 
    Map<String, dynamic> noteData,
    DateTime? remoteUpdatedAt,
    int? localId
  ) async {
    // 1. 查找本地对应的笔记
    final localNotes = await _database.noteDao.getAllNotes();
    final localNote = localNotes.where((note) => note.firestoreId == firestoreId).firstOrNull;
    
    if (localNote == null) {
      // 本地不存在此笔记，视为新增处理
      await _handleRemoteNoteAdded(firestoreId, noteData);
      return;
    }
    
    // 2. 比较更新时间，仅当云端更新时间更晚时才更新本地
    if (remoteUpdatedAt != null && 
        (localNote.lastSyncedAt == null || remoteUpdatedAt.isAfter(localNote.lastSyncedAt!))) {
      // 云端数据更新，更新本地数据
      final updatedNote = localNote.copyWith(
        title: noteData['title'] as String? ?? localNote.title,
        content: noteData['content'] as String? ?? localNote.content,
        locationInfo: Value(noteData['locationInfo'] as String?),
        color: Value(noteData['color'] as int?),
        isPinned: noteData['isPinned'] as bool? ?? localNote.isPinned,
        isArchived: noteData['isArchived'] as bool? ?? localNote.isArchived,
        isDeleted: noteData['isDeleted'] as bool? ?? localNote.isDeleted,
        thumbnailMode: noteData['thumbnailMode'] as bool? ?? localNote.thumbnailMode,
        syncStatus: 'synced',
        lastSyncedAt: Value(remoteUpdatedAt),
      );
      
      await _database.noteDao.updateNote(updatedNote.toCompanion(true));
      _logger.d('Updated local note ${localNote.id} with cloud changes');
    } else {
      _logger.d('Cloud note not newer than local, skipping update');
    }
  }
  
  /// 处理云端删除笔记
  Future<void> _handleRemoteNoteRemoved(String firestoreId) async {
    // 1. 查找本地对应的笔记
    final localNotes = await _database.noteDao.getAllNotes();
    final localNote = localNotes.where((note) => note.firestoreId == firestoreId).firstOrNull;
    
    if (localNote == null) {
      // 本地不存在此笔记，无需处理
      return;
    }
    
    // 2. 在本地也删除此笔记
    await _database.noteDao.softDeleteNote(localNote.id);
    _logger.d('Soft-deleted local note ${localNote.id} based on cloud deletion');
  }
  
  // --- 标签变化监听 ---
  
  /// 监听标签集合的变化
  void _listenForTagChanges() {
    _firestore.collection('tags').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        // 可以实现类似笔记变更的处理逻辑
        // 但为简化代码，这里省略
      }
    }, onError: (e) {
      _logger.e('Error listening for tag changes: $e');
    });
  }
  
  // --- 聊天历史变化监听 ---
  
  /// 监听聊天历史集合的变化
  void _listenForChatHistoryChanges() {
    _firestore.collection('chatHistories').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        // 可以实现类似笔记变更的处理逻辑
        // 但为简化代码，这里省略
      }
    }, onError: (e) {
      _logger.e('Error listening for chat history changes: $e');
    });
  }
  
  // --- 聊天消息变化监听 ---
  
  /// 监听聊天消息集合的变化
  void _listenForChatMessageChanges() {
    _firestore.collection('chatMessages').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        // 可以实现类似笔记变更的处理逻辑
        // 但为简化代码，这里省略
      }
    }, onError: (e) {
      _logger.e('Error listening for chat message changes: $e');
    });
  }
} 