// lib/data/database/connection/web.dart

import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:record_app/data/database/database.dart';

AppDatabase connect() {
  return AppDatabase(DatabaseConnection.delayed(Future(() async {
    final result = await WasmDatabase.open(
      databaseName: 'record-db', // 数据库在浏览器中的名字
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );

    if (result.missingFeatures.isNotEmpty) {
      print('Unsupported features: ${result.missingFeatures}');
    }

    return result.resolvedExecutor;
  })));
}