import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/ai_chat_bloc.dart';

/// AI聊天页面的AppBar
class AiChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  const AiChatAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('AI助手'),
      centerTitle: true,
      actions: [
        // 清除聊天记录按钮
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('清除聊天记录'),
                content: const Text('确定要清除所有聊天记录吗？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () {
                      // 调用bloc的清除事件
                      context.read<AiChatBloc>().add(const AiChatCleared());
                      Navigator.of(context).pop();
                    },
                    child: const Text('确定'),
                  ),
                ],
              ),
            );
          },
        ),
        // 查看帮助按钮
        IconButton(
          icon: const Icon(Icons.help_outline),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('AI助手使用指南'),
                content: const SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('你可以：', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('• 询问AI有关你笔记的信息'),
                      Text('• 使用"@标签名"来查询特定标签的笔记'),
                      Text('• 请求AI总结某个时间段或地点的笔记'),
                      Text('• 让AI帮你寻找特定笔记内容'),
                      SizedBox(height: 16),
                      Text('示例：', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('• "总结我最近一周的笔记"'),
                      Text('• "查找我关于@工作的笔记"'),
                      Text('• "在上海的笔记有哪些？"'),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('了解'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
} 