import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:record/core/utils/date_extensions.dart';
import 'package:record/data/database/database.dart';
import 'package:record/features/home/presentation/widgets/note_location.dart';
import 'package:record/features/home/presentation/widgets/note_tags.dart';

/// 笔记卡片组件，用于显示笔记列表中的单个笔记项
class NoteCard extends StatelessWidget {
  /// 笔记数据
  final Note note;
  
  /// 删除笔记回调
  final void Function(int noteId)? onDelete;
  
  /// 恢复笔记回调
  final void Function(int noteId)? onRestore;
  
  const NoteCard({
    super.key,
    required this.note,
    this.onDelete,
    this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: Key(note.id.toString()),
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            onPressed: (context) => _handleDelete(context),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: '删除',
          ),
        ],
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: InkWell(
          onTap: () => _navigateToDetail(context),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 左侧内容
                  Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                Text(
                  note.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                
                // 标签组件
                NoteTagsWidget(noteId: note.id),
                
                const SizedBox(height: 4), // 减少间距
                
                // 创建时间和位置信息垂直排列在左侧
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 时间
                        Text(
                          note.createdAt.toYYMMDD(),
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                        ),
                        // 位置信息
                        if (note.locationInfo != null && note.locationInfo!.isNotEmpty)
                          const SizedBox(height: 1), // 更小的间距
                        if (note.locationInfo != null && note.locationInfo!.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on_outlined, size: 10, color: Colors.grey.shade600),
                              const SizedBox(width: 2), // 更小的间距
                              Flexible(
                                child: Text(
                                  note.locationInfo!,
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
                  ),
                  
                  // 右侧笔记图片（如果有）
                  _NoteImagePreview(noteId: note.id),
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  /// 处理删除操作
  void _handleDelete(BuildContext context) {
    onDelete?.call(note.id);
    
    // 如果有还原回调，显示撤销操作的提示
    if (onRestore != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('笔记已删除'),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () {
              onRestore?.call(note.id);
            },
          ),
        ),
      );
    }
  }
  
  /// 导航到笔记详情页面
  void _navigateToDetail(BuildContext context) {
    context.goNamed(
      'noteDetail', 
      pathParameters: {'id': note.id.toString()}, 
      extra: note
    );
  }
}

/// 笔记图片预览组件
class _NoteImagePreview extends StatelessWidget {
  final int noteId;
  final double width;
  
  const _NoteImagePreview({
    required this.noteId,
    this.width = 70,
  });
  
  @override
  Widget build(BuildContext context) {
    final database = Provider.of<AppDatabase>(context, listen: false);
    
    return StreamBuilder<List<NoteImage>>(
      stream: database.noteDao.watchImagesForNote(noteId),
      builder: (context, snapshot) {
        final images = snapshot.data ?? [];
        
        if (images.isEmpty) {
          return const SizedBox.shrink(); // 没有图片时不显示
        }
        
        // 只显示第一张图片
        final firstImagePath = images.first.path;
        
        return Container(
          width: width,
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
          ),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 1.0, // 1:1 比例确保是正方形
            child: _buildImage(firstImagePath),
          ),
        );
      },
    );
  }
  
  Widget _buildImage(String path) {
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      width: width,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey.shade200,
          child: Icon(
            Icons.broken_image,
            color: Colors.grey.shade400,
          ),
        );
      },
    );
  }
} 