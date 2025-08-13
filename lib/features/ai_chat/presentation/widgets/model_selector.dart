import 'package:flutter/material.dart';

/// 可用的AI模型
enum AiModel {
  gemini25Flash,
  gemini25Pro,
  gemini20Flash,
}

/// AI模型扩展
extension AiModelExtension on AiModel {
  /// 获取模型显示名称
  String get displayName {
    switch (this) {
      case AiModel.gemini25Flash:
        return '2.5 Flash';
      case AiModel.gemini25Pro:
        return '2.5 Pro';
      case AiModel.gemini20Flash:
        return '2.0 Flash';
    }
  }

  /// 获取模型技术名称
  String get technicalName {
    switch (this) {
      case AiModel.gemini25Flash:
        return 'gemini-2.5-flash';
      case AiModel.gemini25Pro:
        return 'gemini-2.5-pro';
      case AiModel.gemini20Flash:
        return 'gemini-2.0-flash';
    }
  }
}

/// AI模型选择器
class ModelSelector extends StatelessWidget {
  /// 当前选择的模型
  final AiModel currentModel;
  
  /// 模型变更回调
  final ValueChanged<AiModel> onModelChanged;
  
  const ModelSelector({
    super.key,
    required this.currentModel,
    required this.onModelChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showModelSelectionDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentModel.displayName, 
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  /// 显示模型选择对话框
  Future<void> _showModelSelectionDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    final AiModel? result = await showDialog<AiModel>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择模型'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: AiModel.values.map((model) {
              return ListTile(
                title: Text(model.displayName),
                subtitle: Text(
                  model.technicalName,
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                selected: model == currentModel,
                trailing: model == currentModel 
                    ? Icon(
                        Icons.check, 
                        color: theme.colorScheme.primary,
                      ) 
                    : null,
                onTap: () {
                  Navigator.of(context).pop(model);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );

    if (result != null && result != currentModel) {
      onModelChanged(result);
    }
  }
} 