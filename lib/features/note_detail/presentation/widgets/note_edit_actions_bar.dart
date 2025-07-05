import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/data/database/database.dart';


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

  const NoteEditActionsBar({
    super.key,
    required this.onInsertText,
    required this.onPickImage,
    required this.onTakePhoto,
    required this.onSave,
    this.onFormatText,
    this.onInsertList,
  });

  @override
  Widget build(BuildContext context) {
    final database = Provider.of<AppDatabase>(context);
    final toolbarIconSize = 20.0;
    
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 格式工具栏
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // 粗体按钮
                IconButton(
                  icon: const Icon(Icons.format_bold),
                  iconSize: toolbarIconSize,
                  onPressed: () {
                    if (onFormatText != null) {
                      onFormatText!('**', '**');
                    } else {
                      onInsertText('**粗体文本**');
                    }
                  },
                  tooltip: '粗体',
                ),
                // 斜体按钮
                IconButton(
                  icon: const Icon(Icons.format_italic),
                  iconSize: toolbarIconSize,
                  onPressed: () {
                    if (onFormatText != null) {
                      onFormatText!('*', '*');
                    } else {
                      onInsertText('*斜体文本*');
                    }
                  },
                  tooltip: '斜体',
                ),
                // 项目符号列表
                IconButton(
                  icon: const Icon(Icons.format_list_bulleted),
                  iconSize: toolbarIconSize,
                  onPressed: () {
                    if (onInsertList != null) {
                      onInsertList!('- ');
                    } else {
                      onInsertText('- 列表项\n');
                    }
                  },
                  tooltip: '项目符号列表',
                ),
                // 数字列表
                IconButton(
                  icon: const Icon(Icons.format_list_numbered),
                  iconSize: toolbarIconSize,
                  onPressed: () {
                    if (onInsertList != null) {
                      onInsertList!('1. ');
                    } else {
                      onInsertText('1. 列表项\n');
                    }
                  },
                  tooltip: '数字列表',
                ),
                // 引用
                IconButton(
                  icon: const Icon(Icons.format_quote),
                  iconSize: toolbarIconSize,
                  onPressed: () {
                    if (onInsertList != null) {
                      onInsertList!('> ');
                    } else {
                      onInsertText('> 引用文本\n');
                    }
                  },
                  tooltip: '引用',
                ),
              ],
            ),
          ),
          
          // 主工具栏
          Row(
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
                ],
              ),
              IconButton(
                onPressed: onSave,
                icon: const Icon(Icons.send),
                tooltip: '保存',
              )
            ],
          ),
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