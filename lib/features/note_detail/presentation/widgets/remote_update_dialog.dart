import 'package:flutter/material.dart';

/// 用于询问用户是否接受云端更新的对话框
class RemoteUpdateDialog extends StatelessWidget {
  final String title;
  final String remoteUpdatedTime;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const RemoteUpdateDialog({
    super.key,
    required this.title,
    required this.remoteUpdatedTime,
    required this.onAccept,
    required this.onReject,
  });

  /// 显示远程更新提示对话框
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String remoteUpdatedTime,
    required VoidCallback onAccept,
    required VoidCallback onReject,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RemoteUpdateDialog(
        title: title,
        remoteUpdatedTime: remoteUpdatedTime,
        onAccept: onAccept,
        onReject: onReject,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('云端版本更新提示'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('发现此笔记的云端版本更新于：$remoteUpdatedTime'),
          const SizedBox(height: 8),
          Text('笔记标题: $title'),
          const SizedBox(height: 16),
          const Text('您希望：'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(false);
            onReject();
          },
          child: const Text('保留本地版本'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(true);
            onAccept();
          },
          child: const Text('使用云端版本'),
        ),
      ],
    );
  }
} 