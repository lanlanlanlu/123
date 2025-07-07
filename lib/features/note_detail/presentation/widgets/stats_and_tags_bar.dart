import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record_app/data/database/database.dart';
import 'package:record_app/data/repository/index.dart';

/// 显示笔记的字数统计和标签的组件
class StatsAndTagsBar extends StatelessWidget {
  /// 阅读模式下使用，从数据库获取标签
  final int? noteId;

  /// 编辑模式下使用，从当前内容中提取标签
  final String? content;
  
  /// 是否处于编辑模式
  final bool isEditing;
  
  /// 标签删除回调
  final Function(String)? onTagRemoved;

  /// 构造函数 - 需要提供noteId或content之一
  const StatsAndTagsBar({
    super.key,
    this.noteId,
    this.content,
    this.isEditing = false,
    this.onTagRemoved,
  }) : assert(noteId != null || content != null, "必须提供noteId或content之一");

  // 提取标签方法 - 确保在所有文本中搜索标签，不仅仅是标题或内容部分
  List<String> _extractTags(String content) {
    if (content.isEmpty) return [];

    final tagRegExp = RegExp(r"#([\p{L}\p{N}_]+)", unicode: true);
    final matches = tagRegExp.allMatches(content);
    return matches.map((match) => match.group(1)!).toSet().toList();
  }

  @override
  Widget build(BuildContext context) {
    final database = Provider.of<AppDatabase>(context);
    final wordCount = content?.trim().isEmpty == false ? content!.trim().length : 0;

    // 阅读模式 - 从数据库获取标签
    if (noteId != null && content == null) {
      return _buildReadModeStats(database, wordCount, noteId!);
    }
    
    // 编辑模式 - 合并当前内容标签和数据库标签
    if (noteId != null && content != null) {
      return _buildEditModeStats(database, wordCount, noteId!, content!);
    }
    
    // 仅内容模式（预览模式）- 只显示从内容提取的标签
    return _buildContentOnlyStats(wordCount, content!);
  }

  // 构建阅读模式下的字数统计和标签显示栏（从数据库获取标签）
  Widget _buildReadModeStats(AppDatabase database, int wordCount, int noteId) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 字数统计
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '$wordCount 字',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ),
        const SizedBox(width: 8),
        // 标签显示 - 从数据库中获取
        Expanded(
          child: StreamBuilder<List<Tag>>(
            stream: database.noteDao.watchTagsForNote(noteId),
            builder: (context, snapshot) {
              final tags = snapshot.data ?? [];
              
              if (tags.isEmpty) return const SizedBox.shrink();
              
              return SizedBox(
                height: 22,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: tags.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    return _buildTagChip(
                      context,
                      tags[index].name,
                      isActive: true,
                      showDeleteButton: false,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // 构建编辑模式下的字数统计和标签显示栏 - 显示所有标签
  Widget _buildEditModeStats(AppDatabase database, int wordCount, int noteId, String content) {
    // 从当前编辑内容中提取的标签
    final extractedTags = _extractTags(content);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 字数统计
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '$wordCount 字',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ),
        const SizedBox(width: 8),
        // 标签显示 - 合并当前编辑内容中的标签和数据库中的标签
        Expanded(
          child: StreamBuilder<List<Tag>>(
            stream: database.noteDao.watchTagsForNote(noteId),
            builder: (context, snapshot) {
              // 获取数据库中的标签
              final dbTags = snapshot.data ?? [];
              final dbTagNames = dbTags.map((tag) => tag.name).toSet();
              
              // 合并数据库标签和提取的标签，确保不重复
              final allTags = <String>{...dbTagNames, ...extractedTags}.toList();
              
              if (allTags.isEmpty) return const SizedBox.shrink();
              
              return SizedBox(
                height: 22,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: allTags.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final tagName = allTags[index];
                    final bool isInCurrentText = extractedTags.contains(tagName);
                    
                    return _buildTagChip(
                      context,
                      tagName,
                      isActive: isInCurrentText,
                      showDeleteButton: isEditing,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // 构建仅基于内容的字数统计和标签显示栏
  Widget _buildContentOnlyStats(int wordCount, String content) {
    // 从当前编辑内容中提取标签
    final extractedTags = _extractTags(content);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 字数统计
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '$wordCount 字',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ),
        const SizedBox(width: 8),
        // 标签显示 - 针对编辑和预览模式，使用从当前内容中提取的标签
        if (extractedTags.isNotEmpty)
          Expanded(
            child: SizedBox(
              height: 22,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: extractedTags.length,
                separatorBuilder: (context, index) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final tagName = extractedTags[index];
                  return _buildTagChip(
                    context,
                    tagName,
                    isActive: true,
                    showDeleteButton: isEditing,
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
  
  // 构建统一的标签组件
  Widget _buildTagChip(
    BuildContext context,
    String tagName, {
    required bool isActive,
    required bool showDeleteButton,
  }) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final tagColor = isActive ? primaryColor.withOpacity(0.1) : Colors.grey.shade100;
    final textColor = isActive ? primaryColor : Colors.grey.shade600;
    
    return Container(
      height: 22,
      padding: EdgeInsets.only(
        left: 8,
        right: showDeleteButton ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: tagColor,
        borderRadius: BorderRadius.circular(11),
        border: isActive ? null : Border.all(color: Colors.grey.shade300, width: 0.5),
        boxShadow: isActive ? [
          BoxShadow(
            color: primaryColor.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ] : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '#$tagName',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
              color: textColor,
            ),
          ),
          if (showDeleteButton)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (onTagRemoved != null) {
                  onTagRemoved!(tagName);
                }
              },
              child: Container(
                margin: const EdgeInsets.only(left: 2),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  size: 10,
                  color: textColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
} 