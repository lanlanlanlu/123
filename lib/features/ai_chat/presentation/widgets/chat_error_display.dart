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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8.0),
      color: Colors.red.shade50,
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close,
              color: Colors.red,
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