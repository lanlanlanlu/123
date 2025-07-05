import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:record/core/widgets/image_context_menu.dart';
import 'package:record/data/database/database.dart';
import 'package:record/features/note_detail/presentation/bloc/note_detail_bloc.dart';
import 'package:record/features/note_detail/presentation/bloc/note_detail_event.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

/// 笔记图片网格组件
class NoteImageGrid extends StatelessWidget {
  /// 笔记ID
  final int noteId;
  
  /// 是否处于编辑模式
  final bool isEditing;
  
  /// 新添加的图片路径列表
  final List<String> newImagePaths;
  
  /// 已删除的图片路径列表
  final List<String> deletedImagePaths;
  
  /// 删除图片的回调
  final Function(String path)? onDeleteImage;

  const NoteImageGrid({
    super.key,
    required this.noteId,
    this.isEditing = false,
    this.newImagePaths = const [],
    this.deletedImagePaths = const [],
    this.onDeleteImage,
  });

  @override
  Widget build(BuildContext context) {
    final database = Provider.of<AppDatabase>(context, listen: false);
    
    return StreamBuilder<List<NoteImage>>(
      stream: database.noteDao.watchImagesForNote(noteId),
      builder: (context, snapshot) {
        final existingImages = snapshot.data ?? [];
        
        // 获取现有图片路径，排除已删除的
        final existingPaths = existingImages
            .map((e) => e.path)
            .where((path) => !deletedImagePaths.contains(path))
            .toList();
        
        // 避免重复添加图片，通过Set来保证唯一性
        final Set<String> allImagePathsSet = Set.from(existingPaths);
        
        // 只添加不在existingPaths中的新图片
        for (final newPath in newImagePaths) {
          allImagePathsSet.add(newPath);
        }
        
        // 转回列表用于显示
        final allImagePaths = allImagePathsSet.toList();

        if (allImagePaths.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                '${allImagePaths.length}张图片',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: allImagePaths.length,
              itemBuilder: (context, index) {
                final imagePath = allImagePaths[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      onLongPress: () {},
                      onLongPressStart: (LongPressStartDetails details) {
                        _showImageContextMenu(context, imagePath, details.globalPosition);
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(imagePath), fit: BoxFit.cover),
                      ),
                    ),
                    if (isEditing && onDeleteImage != null)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => onDeleteImage!(imagePath),
                          child: const CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
  
  // 显示图片上下文菜单
  void _showImageContextMenu(BuildContext context, String path, Offset tapPosition) {
    ImageContextMenu.show(
      context: context,
      position: tapPosition,
      onThumbnailMode: () {
        // 触发小图模式切换事件（此时实际是切换到大图模式）
        context.read<NoteDetailBloc>().add(const NoteDetailToggleThumbnailMode());
      },
      thumbnailModeText: "大图模式", // 小图模式下显示为"大图模式"
      onCopy: () => _copyImageToClipboard(context, path),
      onShare: () => _shareImage(context, path),
      onSave: () => _saveImage(context, path),
      onDelete: isEditing && onDeleteImage != null ? () => onDeleteImage!(path) : null,
    );
  }
  
  // 复制图片到剪贴板
  Future<void> _copyImageToClipboard(BuildContext context, String path) async {
    try {
      await Clipboard.setData(ClipboardData(text: path));
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('图片路径已复制到剪贴板'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('复制失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  // 分享图片
  Future<void> _shareImage(BuildContext context, String path) async {
    try {
      await Share.share(path, subject: '分享图片');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('分享失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
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
} 