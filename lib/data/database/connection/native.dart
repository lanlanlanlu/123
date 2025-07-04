import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:record/data/database/database.dart';

// 使用单例模式保存数据库实例
AppDatabase? _databaseInstance;

// 使用优化后的方法连接数据库
AppDatabase connect() {
  // 如果已经有实例，直接返回
  if (_databaseInstance != null) {
    return _databaseInstance!;
  }
  
  // 创建新实例
  _databaseInstance = AppDatabase(LazyDatabase(() async {
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'record.sqlite'));
      
      // 使用Drift推荐的方法在后台线程中打开数据库
      return NativeDatabase.createInBackground(file, setup: (db) {
        // 启用外键支持
        db.execute('PRAGMA foreign_keys = ON');
        // 启用WAL模式，提高性能和并发能力
        db.execute('PRAGMA journal_mode = WAL');
      });
    } catch (e) {
      print('Failed to initialize database: $e');
      // 如果优化方法失败，使用最基本的连接方式
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'record.sqlite'));
      return NativeDatabase(file);
    }
  }));
  
  return _databaseInstance!;
}

/// 关闭数据库连接并重置单例
Future<void> closeDatabase() async {
  if (_databaseInstance != null) {
    await _databaseInstance!.close();
    _databaseInstance = null;
  }
}