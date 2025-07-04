import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/data/database/database.dart';
import 'package:record/features/main_shell/presentation/widgets/format_menu_sheet.dart';

/// 笔记输入工具栏组件
class NoteInputToolbar extends StatelessWidget {
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

  /// 显示标签菜单
  Future<void> _showTagMenu(BuildContext context) async {
    // 如果没有提供标签按钮的Key，无法显示菜单
    if (tagButtonKey == null) {
      onInsertText('#');
      return;
    }
    
    final database = Provider.of<AppDatabase>(context, listen: false);
    final renderBox = tagButtonKey!.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      onInsertText('#');
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
        onInsertText('#${selectedTag.name} ');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const SizedBox(width: 8),
            IconButton(
              key: tagButtonKey,
              onPressed: () => onInsertText('#'),
              // onPressed: () => _showTagMenu(context),
              icon: const Icon(Icons.tag),
              tooltip: '添加标签',
            ),
            IconButton(
              onPressed: () => onInsertText('@'),
              icon: const Icon(Icons.add_location_outlined),
              tooltip: '添加位置',
            ),
            IconButton(
              onPressed: () => FormatMenuSheet.show(context, onInsertText),
              icon: const Icon(Icons.text_format),
              tooltip: 'Markdown格式',
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.image_outlined),
              tooltip: '添加图片',
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.camera_alt_outlined),
              tooltip: '拍照',
            ),
          ],
        ),
        IconButton(
          onPressed: () async {
            try {
              await onSaveNote();
            } catch (e) {
              // 错误处理已经在NoteInputSheet中完成
            }
          },
          icon: const Icon(Icons.send_outlined),
          tooltip: '保存',
        )
      ],
    );
  }
} 