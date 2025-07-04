import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/data/database/database.dart';

/// 显示笔记的字数统计和标签的组件
class StatsAndTagsBar extends StatelessWidget {
  /// 阅读模式下使用，从数据库获取标签
  final int? noteId;

  /// 编辑模式下使用，从当前内容中提取标签
  final String? content;

  /// 构造函数 - 需要提供noteId或content之一
  const StatsAndTagsBar({
    super.key,
    this.noteId,
    this.content,
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
        Text(
          '$wordCount 字',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
                height: 24,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: tags.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 4),
                  itemBuilder: (context, index) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '#${tags[index].name}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
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
        Text(
          '$wordCount 字',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
                height: 24,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: allTags.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 4),
                  itemBuilder: (context, index) {
                    final tagName = allTags[index];
                    final bool isInCurrentText = extractedTags.contains(tagName);
                    
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isInCurrentText ? Colors.grey.shade200 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: isInCurrentText ? null : Border.all(color: Colors.grey.shade300, width: 1),
                      ),
                      child: Text(
                        '#$tagName',
                        style: TextStyle(
                          fontSize: 12,
                          color: isInCurrentText ? Theme.of(context).primaryColor : Colors.grey.shade600,
                        ),
                      ),
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
        Text(
          '$wordCount 字',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(width: 8),
        // 标签显示 - 针对编辑和预览模式，使用从当前内容中提取的标签
        if (extractedTags.isNotEmpty)
          Expanded(
            child: SizedBox(
              height: 24,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: extractedTags.length,
                separatorBuilder: (context, index) => const SizedBox(width: 4),
                itemBuilder: (context, index) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '#${extractedTags[index]}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
} 