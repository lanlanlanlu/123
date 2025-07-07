import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/data/database/database.dart';
import 'package:record/features/main_shell/presentation/widgets/format_menu_sheet.dart';

/// 笔记输入工具栏组件
class NoteInputToolbar extends StatefulWidget {
  /// 插入文本的回调
  final Function(String) onInsertText;
  
  /// 保存笔记的回调
  final Future<void> Function() onSaveNote;
  
  /// 标签按钮的Key
  final GlobalKey? tagButtonKey;

  const NoteInputToolbar({
    super.key,
    required this.onInsertText,
    required this.onSaveNote,
    this.tagButtonKey,
  });

  @override
  State<NoteInputToolbar> createState() => _NoteInputToolbarState();
}

class _NoteInputToolbarState extends State<NoteInputToolbar> {
  // 跟踪当前活跃的二级菜单
  String? _activeSubmenu;

  /// 显示标签菜单
  Future<void> _showTagMenu(BuildContext context) async {
    // 如果没有提供标签按钮的Key，无法显示菜单
    if (widget.tagButtonKey == null) {
      widget.onInsertText('#');
      return;
    }
    
    final database = Provider.of<AppDatabase>(context, listen: false);
    final renderBox = widget.tagButtonKey!.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      widget.onInsertText('#');
      return;
    }

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    // 在显示菜单之前，先用 await 获取到最近的标签列表
    final List<Tag> recentTags = await database.tagDao.watchRecentTags().first;

    if (context.mounted) {
      // 使用获取到的静态列表来构建菜单项
      final selectedTag = await showMenu<Tag>(
        context: context,
        position: RelativeRect.fromLTRB(
          offset.dx,
          offset.dy - (recentTags.length * 48.0) - 16, // 向上偏移，再加一点边距
          offset.dx + size.width,
          offset.dy,
        ),
        items: recentTags.isNotEmpty
            ? recentTags.map((tag) {
                return PopupMenuItem<Tag>(
                  value: tag,
                  child: Text(tag.name),
                );
              }).toList()
            : [
                const PopupMenuItem(
                  enabled: false,
                  child: Text("无最近标签"),
                ),
              ],
      );

      // 处理返回结果
      if (selectedTag != null) {
        widget.onInsertText('#${selectedTag.name} ');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 主工具栏
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const SizedBox(width: 8),
                IconButton(
                  key: widget.tagButtonKey,
                  onPressed: () => widget.onInsertText('#'),
                  // onPressed: () => _showTagMenu(context),
                  icon: const Icon(Icons.tag),
                  tooltip: '添加标签',
                ),
                IconButton(
                  onPressed: () => widget.onInsertText('@'),
                  icon: const Icon(Icons.add_location_outlined),
                  tooltip: '添加位置',
                ),
                IconButton(
                  onPressed: () => FormatMenuSheet.show(context, widget.onInsertText),
                  icon: const Icon(Icons.text_format),
                  tooltip: 'Markdown格式',
                ),
                // 图片按钮 - 修改为触发二级菜单
                IconButton(
                  onPressed: () {
                    setState(() {
                      _activeSubmenu = _activeSubmenu == 'image' ? null : 'image';
                    });
                  },
                  icon: const Icon(Icons.image_outlined),
                  tooltip: '图片选项',
                  color: _activeSubmenu == 'image' ? Theme.of(context).primaryColor : null,
                ),
              ],
            ),
            IconButton(
              onPressed: () async {
                try {
                  await widget.onSaveNote();
                } catch (e) {
                  // 错误处理已经在NoteInputSheet中完成
                }
              },
              icon: const Icon(Icons.send_outlined),
              tooltip: '保存',
            )
          ],
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
        return _buildImageSubmenu(context);
      default:
        return const SizedBox.shrink();
    }
  }
  
  // 构建图片二级菜单
  Widget _buildImageSubmenu(BuildContext context) {
    return Container(
      key: const ValueKey<String>('image_submenu'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      color: Theme.of(context).canvasColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 图片或视频选项
          _buildSubmenuOption(
            icon: Icons.photo_library,
            label: '图片或视频',
            onTap: () {
              // 这里暂时只是关闭菜单，实际应该调用图片选择功能
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('选择图片功能即将上线')),
              );
              setState(() {
                _activeSubmenu = null; // 关闭二级菜单
              });
            },
            color: Colors.deepPurple,
            backgroundColor: Colors.deepPurple.withOpacity(0.1),
          ),
          
          // 拍照选项
          _buildSubmenuOption(
            icon: Icons.camera_alt,
            label: '拍照',
            onTap: () {
              // 这里暂时只是关闭菜单，实际应该调用拍照功能
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('拍照功能即将上线')),
              );
              setState(() {
                _activeSubmenu = null; // 关闭二级菜单
              });
            },
            color: Colors.deepPurple,
            backgroundColor: Colors.deepPurple.withOpacity(0.1),
          ),
          
          // 文档扫描选项
          _buildSubmenuOption(
            icon: Icons.document_scanner,
            label: '文档扫描',
            onTap: () {
              // 暂未实现文档扫描功能
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('文档扫描功能即将上线')),
              );
              setState(() {
                _activeSubmenu = null; // 关闭二级菜单
              });
            },
            color: Colors.deepPurple,
            backgroundColor: Colors.deepPurple.withOpacity(0.1),
          ),
        ],
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
} 