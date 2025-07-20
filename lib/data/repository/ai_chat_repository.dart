import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:record_app/data/models/chat_reference.dart';
import 'package:record_app/data/models/chat_request.dart';
import 'package:record_app/data/database/connection/connection.dart' as connection;
import 'package:record_app/data/database/database.dart';
import 'package:record_app/data/repository/notes_repository.dart';

class AiChatRepository {
  late final Dio _dio;
  late final AppDatabase _database;

  AiChatRepository() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));
    
    // 初始化数据库连接
    _database = connection.connect();
  }

  // 获取本地服务器的正确地址
  String get _apiBaseUrl {
    // 对于安卓模拟器，主机PC的localhost是 10.0.2.2
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    } 
    // 对于iOS模拟器或桌面平台，可以直接用 localhost
    else {
      return 'http://192.168.150.1:8000';
    }
    // 注意: 如果你使用物理手机进行调试，需要将这里的地址换成你电脑的局域网IP
    // 例如: 'http://192.168.150.1:8000'
  }

  // 发送问题并获取AI的回答
  Future<String> getAiResponse(String query, {List<ChatReference>? references}) async {
    try {
      // 处理引用，填充内容
      List<ChatReference> enrichedReferences = [];
      if (references != null && references.isNotEmpty) {
        enrichedReferences = await _enrichReferences(references);
      }
      
      // 创建请求对象
      final chatRequest = ChatRequest(
        query: query,
        references: enrichedReferences,
      );

      final response = await _dio.post(
        '$_apiBaseUrl/api/chat',
        data: chatRequest.toJson(),
      );

      if (response.statusCode == 200 && response.data != null) {
        // 解析后端返回的 JSON 数据
        return response.data['response'] ?? '抱歉，未能解析返回结果。';
      } else {
        throw Exception('服务器返回了错误状态: ${response.statusCode}');
      }
    } on DioException catch (e) {
      // 处理网络错误
      String errorMessage = '网络请求失败，请检查后端服务是否正在运行。';
      if (e.response != null) {
        errorMessage += '\n错误详情: ${e.response?.data}';
      } else {
        errorMessage += '\nDio 错误: ${e.message}';
      }
      throw Exception(errorMessage);
    } catch (e) {
      // 处理其他未知错误
      throw Exception('发生未知错误: $e');
    }
  }
  
  /// 丰富引用对象，为其填充内容
  Future<List<ChatReference>> _enrichReferences(List<ChatReference> references) async {
    List<ChatReference> result = [];
    
    for (var reference in references) {
      switch (reference.type) {
        case ReferenceType.note:
          // 获取笔记内容
          final note = await _database.noteDao.getNoteById(int.parse(reference.id));
          if (note != null) {
            result.add(ChatReference(
              id: reference.id,
              title: reference.title,
              type: reference.type,
              content: note.content, // 添加笔记内容
            ));
          } else {
            // 保留原始引用，但没有内容
            result.add(reference);
          }
          break;
          
        case ReferenceType.tag:
          // 获取与标签相关的笔记概要
          final taggedNotes = await _database.noteDao.watchNotesByTagName(reference.title).first;
          if (taggedNotes.isNotEmpty) {
            // 生成标签相关内容摘要
            String summary = '标签 "${reference.title}" 相关的笔记:\n';
            for (var note in taggedNotes.take(3)) {
              summary += '- ${note.title}\n';
            }
            if (taggedNotes.length > 3) {
              summary += '... 等共${taggedNotes.length}篇笔记';
            }
            
            result.add(ChatReference(
              id: reference.id,
              title: reference.title,
              type: reference.type,
              content: summary,
            ));
          } else {
            result.add(reference);
          }
          break;
          
        case ReferenceType.location:
          // 获取与地点相关的笔记概要
          final notesRepository = NotesRepository(_database);
          final locationNotes = await notesRepository.watchNotesByLocation(reference.title).first;
          
          if (locationNotes.isNotEmpty) {
            // 生成地点相关内容摘要
            String summary = '地点 "${reference.title}" 相关的笔记:\n';
            for (var note in locationNotes.take(3)) {
              summary += '- ${note.title}\n';
            }
            if (locationNotes.length > 3) {
              summary += '... 等共${locationNotes.length}篇笔记';
            }
            
            result.add(ChatReference(
              id: reference.id,
              title: reference.title,
              type: reference.type,
              content: summary,
            ));
          } else {
            result.add(reference);
          }
          break;
      }
    }
    
    return result;
  }
}