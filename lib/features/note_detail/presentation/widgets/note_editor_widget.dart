import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:record/core/widgets/image_context_menu.dart';
import 'package:record/features/note_detail/presentation/widgets/stats_and_tags_bar.dart';
import 'package:share_plus/share_plus.dart';

/// 笔记编辑模式组件
class NoteEditorWidget extends StatelessWidget {
  /// 标题控制器
  final TextEditingController titleController;
  
  /// 内容控制器
  final TextEditingController textController;
  
  /// 内容焦点节点
  final FocusNode focusNode;
  
  /// 笔记ID
  final int noteId;
  
  /// 标题变化回调
  final Function(String) onTitleChanged;
  
  /// 删除图片回调
  final Function(String)? onDeleteImage;

  const NoteEditorWidget({
    super.key,
    required this.titleController,
    required this.textController,
    required this.focusNode,
    required this.noteId,
    required this.onTitleChanged,
    this.onDeleteImage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题输入框
        TextField(
          controller: titleController,
          decoration: const InputDecoration(
            hintText: '标题',
            hintStyle: TextStyle(color: Colors.grey),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          style: const TextStyle(
            fontSize: 20, 
            fontWeight: FontWeight.bold,
            height: 1.5,
            color: Colors.black87,
          ),
          onChanged: onTitleChanged,
        ),
        
        // 字数统计和标签显示栏
        Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
          child: StatsAndTagsBar(
            noteId: noteId,
            content: textController.text,
          ),
        ),
        
        // 内容输入框
        TextField(
          controller: textController,
          focusNode: focusNode,
          maxLines: null,
          style: const TextStyle(
            fontSize: 16, 
            height: 1.5, 
            color: Colors.black87
          ),
          decoration: const InputDecoration(border: InputBorder.none),
        ),
        
        // 实时预览图片（保持原始尺寸）
        _MarkdownImagesPreview(
          content: textController.text,
          textController: textController,
          onDeleteImage: onDeleteImage,
        ),
      ],
    );
  }
}

/// 用于实时预览内容中的图片
class _MarkdownImagesPreview extends StatelessWidget {
  final String content;
  final TextEditingController textController;
  final Function(String)? onDeleteImage;

  const _MarkdownImagesPreview({
    required this.content,
    required this.textController,
    this.onDeleteImage,
  });

  @override
  Widget build(BuildContext context) {
    // 提取Markdown中的图片链接
    final imageRegex = RegExp(r'!\[.*?\]\((.*?)\)');
    final matches = imageRegex.allMatches(content);
    
    // 如果没有图片，不显示任何内容
    if (matches.isEmpty) {
      return const SizedBox.shrink();
    }

    // 提取所有图片路径和对应的Markdown语法
    final imageData = matches.map((match) {
      final fullMatch = match.group(0)!;
      final path = match.group(1)!;
      return MapEntry(path, fullMatch);
    }).toList();
    
    // 获取屏幕宽度以适配图片大小
    final screenWidth = MediaQuery.of(context).size.width;
    final imageWidth = screenWidth - 48.0; // 减去左右边距
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const Padding(
          padding: EdgeInsets.only(top: 4.0, bottom: 8.0),
          child: Text(
            '图片预览',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ),
        // 显示图片，自适应屏幕宽度并保持比例
        Column(
          children: imageData.map((entry) => 
            _buildImagePreview(
              context, 
              entry.key, 
              entry.value,
              imageWidth,
            )
          ).toList(),
        ),
      ],
    );
  }

  Widget _buildImagePreview(
    BuildContext context, 
    String path, 
    String markdownSyntax,
    double maxWidth
  ) {
    return GestureDetector(
      onLongPress: () {},
      onLongPressStart: (LongPressStartDetails details) {
        _showImageContextMenu(context, path, markdownSyntax, details.globalPosition);
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: Image.file(
            File(path),
            width: maxWidth,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: maxWidth,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: const Icon(Icons.broken_image, color: Colors.grey),
              );
            },
          ),
        ),
      ),
    );
  }
  
  // 显示图片上下文菜单
  void _showImageContextMenu(BuildContext context, String path, String markdownSyntax, Offset tapPosition) {
    ImageContextMenu.show(
      context: context,
      position: tapPosition,
      onThumbnailMode: () {
        // 小图模式未实现
      },
      onCopy: () => _copyImageToClipboard(context, path),
      onShare: () => _shareImage(context, path),
      onSave: () => _saveImage(context, path),
      onDelete: () => _deleteImage(context, path, markdownSyntax),
    );
  }
  
  // 复制图片到剪贴板
  Future<void> _copyImageToClipboard(BuildContext context, String path) async {
    try {
      await Clipboard.setData(ClipboardData(text: path));
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('图片路径已复制到剪贴板'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('复制失败: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
  
  // 分享图片
  Future<void> _shareImage(BuildContext context, String path) async {
    try {
      await Share.share(path, subject: '分享图片');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('分享失败: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
  
  // 保存图片（这里只显示提示，因为图片已经在本地了）
  void _saveImage(BuildContext context, String path) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('图片已保存在: $path'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  // 删除图片
  void _deleteImage(BuildContext context, String path, String markdownSyntax) {
    // 从文本中删除Markdown语法
    final currentText = textController.text;
    final newText = currentText.replaceAll(markdownSyntax, '');
    textController.text = newText;
    
    // 调用删除图片回调
    onDeleteImage?.call(path);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('图片已删除'),
        duration: Duration(seconds: 2),
      ),
    );
  }
} 