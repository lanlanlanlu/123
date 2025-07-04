import 'package:flutter/material.dart';

/// 用于在编辑笔记时插入Markdown格式的菜单
class MarkdownFormatMenu extends StatelessWidget {
  /// 插入文本的回调
  final Function(String text) onInsertText;

  const MarkdownFormatMenu({
    super.key,
    required this.onInsertText,
  });

  /// 显示底部格式菜单
  static void show(BuildContext context, Function(String text) onInsertText) {
    showModalBottomSheet(
      context: context,
      builder: (context) => MarkdownFormatMenu(
        onInsertText: onInsertText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Markdown格式指南', 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFormatButton(context, '**粗体**', '**粗体文本**'),
              _buildFormatButton(context, '*斜体*', '*斜体文本*'),
              _buildFormatButton(context, '# 标题', '# 一级标题\n'),
              _buildFormatButton(context, '- 列表', '- 列表项\n'),
              _buildFormatButton(context, '1. 有序', '1. 有序列表项\n'),
              _buildFormatButton(context, '[链接](url)', '[链接文本](https://example.com)'),
              _buildFormatButton(context, '![图片](url)', '![图片描述](图片链接)'),
              _buildFormatButton(context, '`代码`', '`代码`'),
              _buildFormatButton(context, '> 引用', '> 引用文本\n'),
              _buildFormatButton(context, '---', '\n---\n'),
              _buildFormatButton(context, '表格', '| 列1 | 列2 |\n|-----|-----|\n| 内容 | 内容 |\n'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormatButton(BuildContext context, String label, String format) {
    return ElevatedButton(
      onPressed: () {
        onInsertText(format);
        Navigator.pop(context);
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(label),
    );
  }
} 