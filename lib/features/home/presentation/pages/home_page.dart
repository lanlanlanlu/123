// lib/features/home/presentation/pages/home_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:record_app/data/repository/index.dart';
import 'package:record_app/features/home/presentation/bloc/app_bar_bloc.dart';
import 'package:record_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:record_app/features/home/presentation/bloc/home_event.dart';
import 'package:record_app/features/home/presentation/bloc/home_state.dart';
import 'package:record_app/features/home/presentation/widgets/empty_notes_view.dart';
import 'package:record_app/features/home/presentation/widgets/note_card.dart';

/// 首页，显示所有笔记列表
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // 【修改】移除了设置透明状态栏的 SystemChrome.setSystemUIOverlayStyle 调用
    
    return BlocProvider(
      create: (context) {
        final notesRepository = context.read<NotesRepository>();
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
    final s = AppLocalizations.of(context)!;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // 【修改】移除了 Scaffold，只返回 body 内容
    return BlocConsumer<HomeBloc, HomeState>(
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
          return Center(
            child: Text(
              '${s.aiChatError}: ${state.message}',
              style: TextStyle(
                color: isDarkMode ? Colors.red[300] : Colors.red,
                fontSize: 16,
              ),
            ),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}