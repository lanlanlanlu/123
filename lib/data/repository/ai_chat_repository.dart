import 'dart:io' show Platform;
import 'package:dio/dio.dart';

class AiChatRepository {
  late final Dio _dio;

  AiChatRepository() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));
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
  Future<String> getAiResponse(String query) async {
    try {
      final response = await _dio.post(
        '$_apiBaseUrl/api/chat',
        data: {'query': query},
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
}