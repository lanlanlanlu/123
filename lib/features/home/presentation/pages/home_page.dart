import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:record/data/repository/index.dart';
import 'package:record/features/home/presentation/bloc/home_bloc.dart';
import 'package:record/features/home/presentation/bloc/home_event.dart';
import 'package:record/features/home/presentation/bloc/home_state.dart';
import 'package:record/features/home/presentation/widgets/custom_app_bar.dart';
import 'package:record/features/home/presentation/widgets/empty_notes_view.dart';
import 'package:record/features/home/presentation/widgets/note_card.dart';

/// 首页，显示所有笔记列表
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        // 优先使用直接注入的NotesRepository
        final notesRepository = 
          context.read<NotesRepository>();
        
        return HomeBloc(notesRepository: notesRepository)
          ..add(const HomeLoadNotes());
      },
      child: const HomeView(),
    );
  }
}



/// 首页视图
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: BlocConsumer<HomeBloc, HomeState>(
        listener: (context, state) {
          if (state is HomeOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is HomeLoadFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          if (state is HomeLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is HomeLoadSuccess) {
            if (state.notes.isEmpty) {
              return const EmptyNotesView();
            }
            
            return ListView.builder(
              itemCount: state.notes.length,
              itemBuilder: (context, index) => NoteCard(
                note: state.notes[index],
                onDelete: (noteId) => context.read<HomeBloc>().add(HomeNoteDeleted(noteId)),
                onRestore: (noteId) => context.read<HomeBloc>().add(HomeNoteRestored(noteId)),
              ),
            );
          } else if (state is HomeLoadFailure) {
            return Center(child: Text('加载失败: ${state.message}'));
          }
          
          // 初始状态或未处理的状态
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}