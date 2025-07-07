import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:record_app/data/database/database.dart';
import 'package:record_app/data/repository/index.dart';
import 'package:record_app/features/tags/presentation/bloc/tag_list_bloc.dart';
import 'package:record_app/features/tags/presentation/pages/tag_detail_page.dart';
import 'package:record_app/features/tags/presentation/pages/tag_categories_page.dart';

class TagListPage extends StatelessWidget {
  const TagListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        // 优先使用直接注入的TagsRepository
        final tagsRepository = 
          context.read<TagsRepository>();
        
        return TagListBloc(tagsRepository: tagsRepository)
          ..add(const TagListLoadTags());
      },
      child: const TagListView(),
    );
  }
}

class TagListView extends StatefulWidget {
  const TagListView({super.key});

  @override
  State<TagListView> createState() => _TagListViewState();
}

class _TagListViewState extends State<TagListView> {
  // 用于跟踪是否有标签被删除
  bool _hasTagDeleted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('所有标签'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(_hasTagDeleted), // 返回时传递是否有标签被删除
        ),
      ),
      body: BlocConsumer<TagListBloc, TagListState>(
        listener: (context, state) {
          if (state is TagListLoaded && state.isAfterDeletion) {
            setState(() {
              _hasTagDeleted = true; // 标记有标签被删除
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('标签已删除')),
            );
          } else if (state is TagOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is TagListError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is TagListLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is TagListLoaded) {
            return _buildTagList(context, state.tags, state.tagYears);
          } else if (state is TagListError) {
            return Center(child: Text('加载失败: ${state.message}'));
          }
          
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
  
  Widget _buildTagList(BuildContext context, List<Tag> tags, Set<String> years) {
    if (tags.isEmpty && years.isEmpty) {
      return const Center(child: Text('没有标签'));
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 年份标签部分
          if (years.isNotEmpty) ...[
            const Text(
              '按年份浏览',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12.0,
              runSpacing: 12.0,
              children: years.map((year) => _buildYearChip(context, year)).toList(),
            ),
            const SizedBox(height: 24),
          ],
          
          // 普通标签部分
          if (tags.isNotEmpty) ...[
            const Text(
              '所有标签',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12.0,
              runSpacing: 12.0,
              children: tags.map((tag) => _buildTagChip(context, tag)).toList(),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildTagChip(BuildContext context, Tag tag) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? const Color(0xFFF0F0F0)
            : Colors.grey[800],
        borderRadius: BorderRadius.circular(32),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
                        MaterialPageRoute(
              builder: (_) => TagDetailPage(tagName: tag.name),
                        ),
                      );
                    },
        borderRadius: BorderRadius.circular(32),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7, // 限制最大宽度为屏幕宽度的70%
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.tag,
                  size: 18,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    tag.name,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _showDeleteConfirmationDialog(context, tag.name),
                  child: const Icon(
                    Icons.close,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
              ),
            );
          }
          
  Widget _buildYearChip(BuildContext context, String year) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? const Color(0xFFE3F2FD) // 浅蓝色背景
            : Colors.blueGrey[800],
        borderRadius: BorderRadius.circular(32),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TagDetailPage(tagName: year, isYearTag: true),
            ),
          );
        },
        borderRadius: BorderRadius.circular(32),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_today,
                size: 18,
                color: Colors.indigo,
              ),
              const SizedBox(width: 8),
              Text(
                '$year年',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Future<void> _showDeleteConfirmationDialog(BuildContext context, String tagName) async {
    // 在显示对话框前先获取bloc
    final tagListBloc = context.read<TagListBloc>();
    
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '温馨提示',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20.0),
                Text(
                  '确定要删除 #$tagName 标签?',
                  style: const TextStyle(fontSize: 16.0),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                        ),
                        child: const Text(
                          '取消',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16.0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16.0),
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          // 使用预先获取的bloc而不是从对话框context中读取
                          tagListBloc.add(TagDeleted(tagName));
                          Navigator.of(dialogContext).pop();
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                        ),
                        child: const Text(
                          '确定',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}