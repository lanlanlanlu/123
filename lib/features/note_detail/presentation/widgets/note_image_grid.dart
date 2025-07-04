import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/data/database/database.dart';

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

        return GridView.builder(
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(imagePath), fit: BoxFit.cover),
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
        );
      },
    );
  }
} 