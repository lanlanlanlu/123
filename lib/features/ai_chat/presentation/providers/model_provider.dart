import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record_app/features/ai_chat/presentation/widgets/model_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AI模型提供者 - 管理当前使用的AI模型和模型选择状态
class ModelProvider with ChangeNotifier {
  /// 模型偏好设置存储键名
  static const String _prefKey = 'ai_model_preference';
  
  /// 当前选定的模型
  AiModel _currentModel = AiModel.gemini25Flash;
  
  /// 获取当前模型
  AiModel get currentModel => _currentModel;
  
  /// 构造函数
  ModelProvider() {
    // 初始化时从SharedPreferences加载保存的模型偏好
    _loadSavedModel();
  }
  
  /// 加载保存的模型设置
  Future<void> _loadSavedModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedModelIndex = prefs.getInt(_prefKey);
      
      if (savedModelIndex != null && savedModelIndex < AiModel.values.length) {
        _currentModel = AiModel.values[savedModelIndex];
        debugPrint('已从偏好设置加载模型: ${_currentModel.technicalName}');
        notifyListeners();
      } else {
        debugPrint('未找到保存的模型偏好，使用默认模型: ${_currentModel.technicalName}');
      }
    } catch (e) {
      debugPrint('加载模型偏好时出错: $e');
    }
  }
  
  /// 更改当前模型
  Future<void> changeModel(AiModel model) async {
    if (_currentModel != model) {
      _currentModel = model;
      
      // 将模型偏好保存到SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_prefKey, model.index);
        
        debugPrint('已将模型切换为: ${model.technicalName}');
        notifyListeners();
      } catch (e) {
        debugPrint('保存模型偏好时出错: $e');
      }
    }
  }
} 