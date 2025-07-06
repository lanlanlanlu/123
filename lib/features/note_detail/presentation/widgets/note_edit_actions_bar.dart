import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/data/database/database.dart';
import 'package:flutter_quill/flutter_quill.dart';


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
  
  /// 格式化文本回调 - 添加粗体、斜体等格式
  final Function(String prefix, String suffix)? onFormatText;
  
  /// 插入列表回调 - 添加项目符号、数字列表等
  final Function(String marker)? onInsertList;
  
  /// QuillController 实例，用于直接控制编辑器
  final QuillController? controller;

  const NoteEditActionsBar({
    super.key,
    required this.onInsertText,
    required this.onPickImage,
    required this.onTakePhoto,
    required this.onSave,
    this.onFormatText,
    this.onInsertList,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final database = Provider.of<AppDatabase>(context);
    const toolbarIconSize = 20.0;
    
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
        children: [
          // 位置按钮
          _buildLocationButton(context, database, toolbarIconSize),
          
          // 标签按钮
          _buildTagButton(context, database, toolbarIconSize),
          
          // 格式化工具栏按钮 (Quill)
          if (controller != null) ...[
            // 加粗
            IconButton(
              icon: const Icon(Icons.format_bold),
              iconSize: toolbarIconSize,
              onPressed: () => _applyFormat(Attribute.bold),
              tooltip: '加粗',
            ),
          ],
          
          // 图片按钮
          IconButton(
            onPressed: onPickImage,
            icon: const Icon(Icons.image_outlined),
            iconSize: toolbarIconSize,
            tooltip: '从相册选择',
          ),
          
          // 相机按钮
          IconButton(
            onPressed: onTakePhoto, 
            icon: const Icon(Icons.camera_alt_outlined),
            iconSize: toolbarIconSize,
            tooltip: '拍照',
          ),
          
          // 右侧空间
          const Spacer(),
          
          // 保存按钮
          IconButton(
            onPressed: onSave,
            icon: const Icon(Icons.send),
            tooltip: '保存',
          )
        ],
      ),
    );
  }
  
  // 应用 Quill 格式
  void _applyFormat(Attribute attribute) {
    if (controller == null) return;
    
    final selection = controller!.selection;
    if (selection.isCollapsed) {
      // 如果没有选中文本，设置格式状态
      controller!.formatSelection(attribute);
    } else {
      // 如果选中了文本，应用格式
      controller!.formatText(
        selection.baseOffset,
        selection.extentOffset - selection.baseOffset,
        attribute,
      );
    }
  }
  
  Widget _buildLocationButton(BuildContext context, AppDatabase database, double iconSize) {
    return StreamBuilder<List<NoteLocation>>(
      stream: database.noteDao.watchLocationsForNote(-1), // 这里应该传入实际的noteId
      builder: (context, snapshot) {
        final locations = snapshot.data ?? [];
        if (locations.isEmpty) {
          return IconButton(
            onPressed: () => onInsertText('@'),
            icon: const Icon(Icons.add_location_outlined),
            iconSize: iconSize,
            tooltip: '添加位置',
          );
        }
        
        return PopupMenuButton<String>(
          icon: const Icon(Icons.add_location_outlined),
          iconSize: iconSize,
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
  
  Widget _buildTagButton(BuildContext context, AppDatabase database, double iconSize) {
    return StreamBuilder<List<Tag>>(
      stream: database.tagDao.watchRecentTags(),
      builder: (context, snapshot) {
        final recentTags = snapshot.data ?? [];
        if (recentTags.isEmpty) {
          return IconButton(
            onPressed: () => onInsertText('#'),
            icon: const Icon(Icons.tag),
            iconSize: iconSize,
            tooltip: '添加标签',
          );
        }
        
        return PopupMenuButton<Tag>(
          icon: const Icon(Icons.tag),
          iconSize: iconSize,
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