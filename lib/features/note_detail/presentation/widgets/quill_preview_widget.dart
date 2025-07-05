import 'dart:io';

import 'package:flutter/material.dart';
import 'package:record/features/note_detail/presentation/widgets/stats_and_tags_bar.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// 基于Flutter Quill的笔记预览组件
class QuillPreviewWidget extends StatefulWidget {
  /// 标题
  final String title;
  
  /// 内容
  final String content;
  
  /// 笔记ID
  final int noteId;
  
  /// 删除图片回调
  final Function(String)? onDeleteImage;

  /// 删除标签回调
  final Function(String)? onTagRemoved;
  
  /// 是否启用小图模式
  final bool thumbnailMode;

  const QuillPreviewWidget({
    super.key,
    required this.title,
    required this.content,
    required this.noteId,
    this.onDeleteImage,
    this.onTagRemoved,
    this.thumbnailMode = false,
  });

  @override
  State<QuillPreviewWidget> createState() => _QuillPreviewWidgetState();
}

class _QuillPreviewWidgetState extends State<QuillPreviewWidget> {
  // 为了简单起见，使用Markdown预览代替Quill预览，避免API版本问题
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 20, 
            fontWeight: FontWeight.bold,
            height: 1.5,
            color: Colors.black87,
          ),
        ),
        
        // 字数统计和标签显示栏
        Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
          child: StatsAndTagsBar(
            noteId: widget.noteId,
            content: widget.content,
            isEditing: false,
            onTagRemoved: widget.onTagRemoved,
          ),
        ),
        
        const SizedBox(height: 8),
        
        // 使用Expanded代替固定高度容器，并移除边框
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              child: MarkdownBody(
                data: widget.content,
                selectable: true,
                imageBuilder: (uri, title, alt) {
                  // 处理本地图片
                  if (!uri.toString().startsWith('http')) {
                    return Image.file(File(uri.toString()));
                  }
                  return Image.network(
                    uri.toString(),
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
} 