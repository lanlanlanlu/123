import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:record/core/widgets/interactive_text.dart';
import 'package:record/data/database/database.dart';
import 'package:record/data/repository/index.dart';
import 'package:record/features/tags/presentation/bloc/tag_detail_bloc.dart';
import 'package:record/core/utils/date_extensions.dart';

class TagDetailPage extends StatelessWidget {
  final String tagName;

  const TagDetailPage({super.key, required this.tagName});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        // 优先使用直接注入的NotesRepository
        final notesRepository = 
          context.read<NotesRepository>();
        
        return TagDetailBloc(notesRepository: notesRepository)
          ..add(TagDetailLoadNotes(tagName));
      },
      child: TagDetailView(tagName: tagName),
    );
  }
}

class TagDetailView extends StatelessWidget {
  final String tagName;

  const TagDetailView({super.key, required this.tagName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('#$tagName'),
      ),
      body: BlocBuilder<TagDetailBloc, TagDetailState>(
        builder: (context, state) {
          if (state is TagDetailLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (state is TagDetailLoaded) {
            final notes = state.notes;

            if (notes.isEmpty) {
              return const Center(
                child: Text('这个标签下没有笔记。'),
              );
            }

            // 这里的笔记列表和主页的几乎一样
            return ListView.builder(
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InteractiveText(
                          text: note.content,
                          style: const TextStyle(fontSize: 16, color: Colors.black87),
                          onTagTap: (tag) {
                            // 在标签详情页，点击标签可以跳转到另一个标签详情页
                            if (tag != tagName) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => TagDetailPage(tagName: tag)),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            note.createdAt.toYYMMDD(),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
          
          if (state is TagDetailError) {
            return Center(child: Text('出错了: ${state.message}'));
          }
          
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}