import 'package:flutter/material.dart';

/// 显示聊天过程中的错误信息
class ChatErrorDisplay extends StatelessWidget {
  final String error;
  
  const ChatErrorDisplay({
    super.key,
    required this.error,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8.0),
      color: isDarkMode 
          ? Color(0xFF4A1515) // 暗红色背景
          : Colors.red.shade50,
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: isDarkMode ? Colors.red[300] : Colors.red,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                color: isDarkMode ? Colors.red[200] : Colors.red.shade700,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              color: isDarkMode ? Colors.red[300] : Colors.red,
              size: 18,
            ),
            onPressed: () {
              // TODO: 清除错误信息
              // 实现中需要调用bloc的事件来清除错误
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
} 