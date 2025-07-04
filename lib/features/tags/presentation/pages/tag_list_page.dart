import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:record/data/database/database.dart';
import 'package:record/data/repository/index.dart';
import 'package:record/features/tags/presentation/bloc/tag_list_bloc.dart';
import 'package:record/features/tags/presentation/pages/tag_detail_page.dart';

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

class TagListView extends StatelessWidget {
  const TagListView({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('所有标签'),
      ),
      body: BlocBuilder<TagListBloc, TagListState>(
        builder: (context, state) {
          if (state is TagListLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (state is TagListLoaded) {
            final tags = state.tags;

            if (tags.isEmpty) {
              return const Center(
                child: Text('还没有任何标签。'),
              );
            }

            // 使用 Wrap 组件来流式布局所有标签
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Wrap(
                spacing: 12.0, // 标签之间的横向间距
                runSpacing: 12.0, // 标签之间的垂直间距
                children: tags.map((tag) {
                  // 使用 ActionChip 来创建一个可点击的、带样式的标签
                  return ActionChip(
                    label: Text(tag.name),
                    labelStyle: TextStyle(color: colors.primary),
                    backgroundColor: colors.primaryContainer.withOpacity(0.3),
                    onPressed: () {
                      // 点击时，跳转到我们之前创建的 TagDetailPage
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TagDetailPage(tagName: tag.name),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            );
          }
          
          if (state is TagListError) {
            return Center(child: Text('出错了: ${state.message}'));
          }
          
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}