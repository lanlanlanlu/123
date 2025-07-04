import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:record/core/widgets/image_context_menu.dart';
import 'package:record/features/note_detail/presentation/widgets/stats_and_tags_bar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// 笔记预览模式组件
class NotePreviewWidget extends StatelessWidget {
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

  const NotePreviewWidget({
    super.key,
    required this.title,
    required this.content,
    required this.noteId,
    this.onDeleteImage,
    this.onTagRemoved,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
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
          
        // 字数统计和标签显示栏
        Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
          child: StatsAndTagsBar(
            noteId: noteId,
            content: content,
            isEditing: true,
            onTagRemoved: onTagRemoved,
          ),
        ),
        
        // Markdown内容预览
        _buildMarkdownPreview(context),
      ],
    );
  }

  Widget _buildMarkdownPreview(BuildContext context) {
    return MarkdownBody(
      data: content,
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
        // 小图模式未实现
      },
      onCopy: () => _copyImageToClipboard(context, path),
      onShare: () => _shareImage(context, path),
      onSave: () => _saveImage(context, path),
      onDelete: isNetwork ? null : () => _deleteImage(context, path),
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
  void _deleteImage(BuildContext context, String path) {
    // 从Markdown中找到对应的图片语法
    final imageRegex = RegExp(r'!\[.*?\]\((.*?)\)');
    final matches = imageRegex.allMatches(content);
    
    for (final match in matches) {
      final matchPath = match.group(1)!;
      if (matchPath == path) {
        // 调用删除图片回调
        onDeleteImage?.call(path);
        break;
      }
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('图片已删除'),
        duration: Duration(seconds: 2),
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