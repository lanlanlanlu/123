import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:record_app/data/models/chat_reference.dart';
import 'package:record_app/data/models/chat_request.dart';
import 'package:record_app/data/database/connection/connection.dart' as connection;
import 'package:record_app/data/database/database.dart';
import 'package:record_app/data/repository/notes_repository.dart';
import 'package:record_app/features/ai_chat/presentation/widgets/model_selector.dart';
import 'package:flutter/foundation.dart';

class AiChatRepository {
  late final Dio _dio;
  late final AppDatabase _database;
  
  /// 当前使用的模型
  AiModel _currentModel = AiModel.gemini25Flash;

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
    // if (Platform.isAndroid) {
    //   return 'http://10.0.2.2:8000';
    // } 
    // // 对于iOS模拟器或桌面平台，可以直接用 localhost
    // else {
    //   return 'http://192.168.150.1:8000';
    // }
    // 注意: 如果你使用物理手机进行调试，需要将这里的地址换成你电脑的局域网IP
    // 例如: 'http://192.168.150.1:8000'
    return 'http://34.142.43.133:8000';
  }
  
  /// 设置当前使用的模型
  void setModel(AiModel model) {
    if (_currentModel != model) {
      debugPrint('AiChatRepository: 模型切换为 ${model.technicalName}');
      _currentModel = model;
      
      // 立即通知服务器模型已变更
      sendModelChangeNotification(model.technicalName);
    }
  }
  
  /// 通知服务器模型变更
  void sendModelChangeNotification(String modelName) {
    try {
      // 发送一个简单的测试查询，主要目的是通知服务器切换模型
      debugPrint('AiChatRepository: 正在发送模型变更通知...');
      
      // 创建一个最小化的请求，避免大量计算
      final chatRequest = ChatRequest(
        query: '模型切换测试 - 请忽略',
        model: modelName,
      );
      
      // 异步发送请求，不等待响应
      _dio.post(
        '$_apiBaseUrl/api/chat',
        data: chatRequest.toJson(),
      ).then((response) {
        if (response.statusCode == 200 && response.data != null) {
          debugPrint('AiChatRepository: 模型变更通知发送成功');
        }
      }).catchError((error) {
        debugPrint('AiChatRepository: 模型变更通知发送失败: $error');
      });
    } catch (e) {
      debugPrint('AiChatRepository: 发送模型变更通知时出错: $e');
    }
  }
  
  /// 获取当前使用的模型
  AiModel get currentModel => _currentModel;

  // 发送问题并获取AI的回答
  Future<String> getAiResponse(
    String query, 
    {List<ChatReference>? references, String? chatId}
  ) async {
    try {
      // 打印详细的调试信息
      print('AiChatRepository: 开始处理请求');
      print('AiChatRepository: 查询: $query');
      print('AiChatRepository: 聊天ID: ${chatId ?? "未提供"}');
      print('AiChatRepository: 引用数量: ${references?.length ?? 0}');
      print('AiChatRepository: 使用模型: ${_currentModel.technicalName}');
      
      // 处理引用，填充内容
      List<ChatReference> enrichedReferences = [];
      if (references != null && references.isNotEmpty) {
        print('AiChatRepository: 开始丰富引用内容...');
        enrichedReferences = await _enrichReferences(references);
        print('AiChatRepository: 引用丰富完成，丰富后数量: ${enrichedReferences.length}');
      }
      
      // 创建请求对象
      final chatRequest = ChatRequest(
        query: query,
        references: enrichedReferences,
        chatId: chatId ?? '', // 添加聊天ID，如果没有则使用空字符串
        model: _currentModel.technicalName, // 添加当前使用的模型名称
      );
      
      // 打印完整请求对象（转为JSON）用于调试
      print('AiChatRepository: 请求对象: ${chatRequest.toJson()}');
      print('AiChatRepository: API基础URL: $_apiBaseUrl');

      print('AiChatRepository: 开始发送POST请求...');
      final response = await _dio.post(
        '$_apiBaseUrl/api/chat',
        data: chatRequest.toJson(),
      );
      print('AiChatRepository: 收到响应，状态码: ${response.statusCode}');

      if (response.statusCode == 200 && response.data != null) {
        // 解析后端返回的 JSON 数据
        print('AiChatRepository: 响应数据: ${response.data}');
        final result = response.data['response'] ?? '抱歉，未能解析返回结果。';
        // 如果返回了使用的模型信息，输出日志
        if (response.data['model'] != null) {
          print('AiChatRepository: 服务器使用的模型: ${response.data['model']}');
        }
        print('AiChatRepository: 解析后的响应: ${result.substring(0, result.length > 50 ? 50 : result.length)}...');
        return result;
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
      print('AiChatRepository: DIO错误: $errorMessage');
      throw Exception(errorMessage);
    } catch (e) {
      // 处理其他未知错误
      print('AiChatRepository: 未知错误: $e');
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