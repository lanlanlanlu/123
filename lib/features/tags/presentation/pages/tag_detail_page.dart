import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:record/data/repository/index.dart';
import 'package:record/features/home/presentation/widgets/empty_notes_view.dart';
import 'package:record/features/home/presentation/widgets/note_card.dart';
import 'package:record/features/tags/presentation/bloc/tag_detail_bloc.dart';

class TagDetailPage extends StatelessWidget {
  final String tagName;
  final bool isYearTag;

  const TagDetailPage({
    super.key, 
    required this.tagName,
    this.isYearTag = false,
  });

  // 判断是否是年份标签（如"2025"）
  static bool isYearTagName(String tagName) {
    return RegExp(r'^[0-9]{4}$').hasMatch(tagName);
  }

  @override
  Widget build(BuildContext context) {
    // 检查是否是年份标签
    final bool isYear = isYearTag || isYearTagName(tagName);
    
    return BlocProvider(
      create: (context) {
        // 优先使用直接注入的NotesRepository
        final notesRepository = 
          context.read<NotesRepository>();
        
        return TagDetailBloc(notesRepository: notesRepository)
          ..add(isYear 
              ? TagDetailLoadNotesByYear(tagName) 
              : TagDetailLoadNotes(tagName));
      },
      child: TagDetailView(tagName: tagName, isYearTag: isYear),
    );
  }
}

class TagDetailView extends StatelessWidget {
  final String tagName;
  final bool isYearTag;

  const TagDetailView({
    super.key, 
    required this.tagName,
    this.isYearTag = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isYearTag ? tagName + '年' : '#$tagName'),
      ),
      body: BlocConsumer<TagDetailBloc, TagDetailState>(
        listener: (context, state) {
          if (state is TagDetailOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is TagDetailError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is TagDetailLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (state is TagDetailLoaded) {
            final notes = state.notes;

            if (notes.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.tag,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isYearTag ? '$tagName年没有笔记' : '这个标签下没有笔记',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('返回'),
                    ),
                  ],
                ),
              );
            }

            // 使用与主页相同的NoteCard组件显示笔记
            return ListView.builder(
              itemCount: notes.length,
              itemBuilder: (context, index) => NoteCard(
                note: notes[index],
                onDelete: (noteId) => context.read<TagDetailBloc>().add(TagDetailNoteDeleted(noteId)),
                onRestore: (noteId) => context.read<TagDetailBloc>().add(TagDetailNoteRestored(noteId)),
                        ),
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