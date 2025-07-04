import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/data/database/database.dart';
import 'package:record/features/note_detail/presentation/widgets/markdown_format_menu.dart';

/// 笔记编辑操作栏组件
class NoteEditActionsBar extends StatelessWidget {
  /// 插入文本的回调
  final Function(String text) onInsertText;
  
  /// 选择图片的回调
  final VoidCallback onPickImage;
  
  /// 拍照的回调
  final VoidCallback onTakePhoto;
  
  /// 保存笔记的回调
  final VoidCallback onSave;

  const NoteEditActionsBar({
    super.key,
    required this.onInsertText,
    required this.onPickImage,
    required this.onTakePhoto,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final database = Provider.of<AppDatabase>(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).canvasColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _buildLocationButton(context, database),
              _buildTagButton(context, database),
              IconButton(
                onPressed: onPickImage,
                icon: const Icon(Icons.image_outlined),
                tooltip: '从相册选择',
              ),
              IconButton(
                onPressed: onTakePhoto, 
                icon: const Icon(Icons.camera_alt_outlined),
                tooltip: '拍照',
              ),
              IconButton(
                onPressed: () => MarkdownFormatMenu.show(context, onInsertText),
                icon: const Icon(Icons.text_format),
                tooltip: 'Markdown格式',
              ),
            ],
          ),
          IconButton(
            onPressed: onSave,
            icon: const Icon(Icons.send),
            tooltip: '保存',
          )
        ],
      ),
    );
  }
  
  Widget _buildLocationButton(BuildContext context, AppDatabase database) {
    return StreamBuilder<List<NoteLocation>>(
      stream: database.noteDao.watchLocationsForNote(-1), // 这里应该传入实际的noteId
      builder: (context, snapshot) {
        final locations = snapshot.data ?? [];
        if (locations.isEmpty) {
          return IconButton(
            onPressed: () => onInsertText('@'),
            icon: const Icon(Icons.add_location_outlined),
            tooltip: '添加位置',
          );
        }
        
        return PopupMenuButton<String>(
          icon: const Icon(Icons.add_location_outlined),
          tooltip: '选择历史位置',
          onSelected: (String value) {
            onInsertText('@$value ');
          },
          itemBuilder: (BuildContext context) {
            return locations.map((loc) {
              return PopupMenuItem<String>(
                value: loc.location,
                child: Text(loc.location),
              );
            }).toList();
          },
        );
      },
    );
  }
  
  Widget _buildTagButton(BuildContext context, AppDatabase database) {
    return StreamBuilder<List<Tag>>(
      stream: database.tagDao.watchRecentTags(),
      builder: (context, snapshot) {
        final recentTags = snapshot.data ?? [];
        if (recentTags.isEmpty) {
          return IconButton(
            onPressed: () => onInsertText('#'),
            icon: const Icon(Icons.tag),
            tooltip: '添加标签',
          );
        }
        
        return PopupMenuButton<Tag>(
          icon: const Icon(Icons.tag),
          tooltip: '选择最近标签',
          onSelected: (Tag tag) {
            onInsertText('#${tag.name} ');
          },
          itemBuilder: (BuildContext context) {
            return recentTags.map((Tag tag) {
              return PopupMenuItem<Tag>(
                value: tag,
                child: Text(tag.name),
              );
            }).toList();
          },
        );
      },
    );
  }
} 