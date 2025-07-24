import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import '../bloc/ai_chat_bloc.dart';
import '../bloc/ai_chat_event.dart';
import '../providers/model_provider.dart';
import '../widgets/model_selector.dart';
import '../../presentation/pages/chat_history_list_page.dart';
import 'package:record_app/data/repository/ai_chat_repository.dart';

/// AI聊天页面的AppBar
class AiChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  const AiChatAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    // 获取AiChatRepository实例
    final aiChatRepository = context.read<AiChatRepository>();
    
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.history, size: 22),
        onPressed: () {
          // 导航到聊天历史列表页面，并提供AiChatRepository
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => Provider<AiChatRepository>.value(
                value: aiChatRepository,
                child: const ChatHistoryListPage(),
              ),
            ),
          );
        },
      ),
      title: Consumer<ModelProvider>(
        builder: (context, modelProvider, child) {
          return ModelSelector(
            currentModel: modelProvider.currentModel,
            onModelChanged: (model) {
              // 更新模型提供者中的模型
              modelProvider.changeModel(model);
              // 更新repository中的模型
              aiChatRepository.setModel(model);
              // 移除SnackBar通知，只保留服务器日志记录
            },
          );
        },
      ),
      centerTitle: true,
      actions: [
        // 清除聊天记录按钮
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 22),
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
          icon: const Icon(Icons.help_outline, size: 22),
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