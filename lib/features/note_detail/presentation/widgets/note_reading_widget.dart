import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:record/core/widgets/image_context_menu.dart';
import 'package:record/data/database/database.dart';
import 'package:record/features/note_detail/presentation/bloc/note_detail_bloc.dart';
import 'package:record/features/note_detail/presentation/bloc/note_detail_event.dart';
import 'package:record/features/note_detail/presentation/widgets/stats_and_tags_bar.dart';
import 'package:record/features/tags/presentation/pages/tag_detail_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// 笔记阅读模式组件
class NoteReadingWidget extends StatelessWidget {
  /// 笔记实体
  final Note note;
  
  /// 点击事件回调
  final VoidCallback onTap;
  
  /// 获取笔记标题的函数
  final String Function(String) getTitleFn;
  
  /// 获取笔记正文的函数
  final String Function(String) getContentBodyFn;
  
  /// 是否在小图模式下
  final bool thumbnailMode;

  const NoteReadingWidget({
    super.key,
    required this.note,
    required this.onTap,
    required this.getTitleFn,
    required this.getContentBodyFn,
    this.thumbnailMode = false,
  });

  @override
  Widget build(BuildContext context) {
    // 使用笔记的标题字段，而不是从内容中提取标题
    final title = note.title;
    // 内容直接使用内容字段，不再需要提取
    final content = note.content;
    final theme = Theme.of(context);
    
    // 使整个内容区域可点击进入编辑模式
    return InkWell(
      onTap: onTap,
      // 移除水波纹效果，使点击更自然
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题显示 - 纯文本，但支持标签交互
          if (title.isNotEmpty)
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
            
          // 添加字数统计和标签栏
          Padding(
            padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
            child: StatsAndTagsBar(
              noteId: note.id,
              content: note.content,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Markdown内容 - 仅用于内容部分
          if (content.isNotEmpty)
            _buildMarkdownPreview(context),
        ],
      ),
    );
  }

  Widget _buildMarkdownPreview(BuildContext context) {
    return MarkdownBody(
      key: ValueKey('markdown_preview_${thumbnailMode ? 'thumbnail' : 'full'}'),
      data: note.content,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
        h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        h2: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        h3: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        h4: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        h5: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        h6: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        blockquote: const TextStyle(
          color: Colors.grey,
          fontStyle: FontStyle.italic,
        ),
        code: const TextStyle(
          backgroundColor: Color(0xFFf7f7f7),
          fontFamily: 'monospace',
        ),
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFFf7f7f7),
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
      onTapLink: (text, href, title) {
        if (href != null) {
          _launchUrl(href);
        }
      },
      imageBuilder: (uri, title, alt) {
        // 在小图模式下不显示图片
        if (thumbnailMode) {
          // 返回空容器以避免在Markdown中留下空间
          return const SizedBox.shrink();
        }
        
        // 处理本地图片
        if (uri.scheme == 'file' || uri.scheme == '') {
          final path = uri.toString().replaceAll('file://', '');
          return _buildImageWidget(context, path);
        }
        // 处理网络图片
        return _buildNetworkImageWidget(context, uri.toString());
      },
    );
  }

  Widget _buildImageWidget(BuildContext context, String path) {
    return GestureDetector(
      onLongPress: () {},
      onLongPressStart: (LongPressStartDetails details) {
        _showImageContextMenu(context, path, details.globalPosition);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: Image.file(
          File(path),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
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
    );
  }

  Widget _buildNetworkImageWidget(BuildContext context, String url) {
    return GestureDetector(
      onLongPress: () {},
      onLongPressStart: (LongPressStartDetails details) {
        _showImageContextMenu(context, url, details.globalPosition, isNetwork: true);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: const Icon(Icons.broken_image, color: Colors.grey),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / 
                        loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // 显示图片上下文菜单
  void _showImageContextMenu(BuildContext context, String path, Offset tapPosition, {bool isNetwork = false}) {
    ImageContextMenu.show(
      context: context,
      position: tapPosition,
      onThumbnailMode: () {
        // 触发小图模式切换事件
        context.read<NoteDetailBloc>().add(const NoteDetailToggleThumbnailMode());
      },
      thumbnailModeText: thumbnailMode ? '大图模式' : '小图模式',
      onCopy: () => _copyImageToClipboard(context, path),
      onShare: () => _shareImage(context, path),
      onSave: () => _saveImage(context, path),
      // 阅读模式不提供删除功能
      onDelete: null,
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
  
  // 打开链接
  Future<void> _launchUrl(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    }
  }
} 