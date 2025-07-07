import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/data/database/database.dart';
import 'package:flutter_quill/flutter_quill.dart';


/// 笔记编辑操作栏组件
class NoteEditActionsBar extends StatefulWidget {
  /// 插入文本的回调
  final Function(String text) onInsertText;
  
  /// 选择图片的回调
  final VoidCallback onPickImage;
  
  /// 选择视频的回调
  final VoidCallback onPickVideo;
  
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
    required this.onPickVideo,
    required this.onTakePhoto,
    required this.onSave,
    this.onFormatText,
    this.onInsertList,
    this.controller,
  });

  @override
  State<NoteEditActionsBar> createState() => _NoteEditActionsBarState();
}

class _NoteEditActionsBarState extends State<NoteEditActionsBar> {
  // 跟踪当前活跃的二级菜单
  String? _activeSubmenu;
  
  @override
  Widget build(BuildContext context) {
    final database = Provider.of<AppDatabase>(context);
    const toolbarIconSize = 20.0;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 主工具栏
        Container(
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
              if (widget.controller != null) ...[
                // 加粗
                IconButton(
                  icon: const Icon(Icons.format_bold),
                  iconSize: toolbarIconSize,
                  onPressed: () => _applyFormat(Attribute.bold),
                  tooltip: '加粗',
                ),
              ],
              
              // 图片按钮 - 修改为触发二级菜单
              IconButton(
                onPressed: () {
                  setState(() {
                    _activeSubmenu = _activeSubmenu == 'image' ? null : 'image';
                  });
                },
                icon: const Icon(Icons.image_outlined),
                iconSize: toolbarIconSize,
                tooltip: '图片选项',
                color: _activeSubmenu == 'image' ? Theme.of(context).primaryColor : null,
              ),
              
              // 右侧空间
              const Spacer(),
              
              // 保存按钮
              IconButton(
                onPressed: widget.onSave,
                icon: const Icon(Icons.send),
                tooltip: '保存',
              )
            ],
          ),
        ),
        
        // 二级菜单区域 - 添加动画效果
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          child: _activeSubmenu != null
            ? _buildSubmenu(context)
            : const SizedBox.shrink(),
        ),
      ],
    );
  }
  
  // 构建二级菜单
  Widget _buildSubmenu(BuildContext context) {
    // 根据当前活跃的二级菜单类型返回对应的菜单
    switch (_activeSubmenu) {
      case 'image':
        return _buildMediaSubmenu(context);
      default:
        return const SizedBox.shrink();
    }
  }
  
  // 构建媒体(图片/视频等)二级菜单
  Widget _buildMediaSubmenu(BuildContext context) {
    final items = [
      (
        icon: Icons.photo_library,
        label: '上传图片',
        onTap: () {
          widget.onPickImage();
          _closeSubmenu();
        },
      ),
      (
        icon: Icons.video_library,
        label: '上传视频',
        onTap: () {
          widget.onPickVideo();
          _closeSubmenu();
        },
      ),
      (
        icon: Icons.camera_alt,
        label: '拍摄照片',
        onTap: () {
          widget.onTakePhoto();
          _closeSubmenu();
        },
      ),
      (
        icon: Icons.videocam,
        label: '拍摄视频',
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('拍摄视频功能即将上线')),
          );
          _closeSubmenu();
        },
      ),
      (
        icon: Icons.document_scanner,
        label: '文档扫描',
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('文档扫描功能即将上线')),
          );
          _closeSubmenu();
        },
      ),
    ];

    return Container(
      key: const ValueKey<String>('media_submenu'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      color: Theme.of(context).canvasColor,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 0.8,
          mainAxisSpacing: 12,
          crossAxisSpacing: 8,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _buildSubmenuOption(
            icon: item.icon,
            label: item.label,
            onTap: item.onTap,
            color: Colors.deepPurple,
            backgroundColor: Colors.deepPurple.withOpacity(0.1),
          );
        },
      ),
    );
  }
  
  // 构建二级菜单选项
  Widget _buildSubmenuOption({
    required IconData icon, 
    required String label, 
    required VoidCallback onTap,
    Color? color,
    Color? backgroundColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.0),
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32.0, color: color),
            const SizedBox(height: 8.0),
            Text(
              label, 
              style: TextStyle(
                fontSize: 13.0,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 应用 Quill 格式
  void _applyFormat(Attribute attribute) {
    if (widget.controller == null) return;
    
    final selection = widget.controller!.selection;
    if (selection.isCollapsed) {
      // 如果没有选中文本，设置格式状态
      widget.controller!.formatSelection(attribute);
    } else {
      // 如果选中了文本，应用格式
      widget.controller!.formatText(
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
            onPressed: () => widget.onInsertText('@'),
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
            widget.onInsertText('@$value ');
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
            onPressed: () => widget.onInsertText('#'),
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
            widget.onInsertText('#${tag.name} ');
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

  void _closeSubmenu() {
    setState(() {
      _activeSubmenu = null;
    });
  }
} 