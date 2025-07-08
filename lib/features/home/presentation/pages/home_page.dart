// lib/features/home/presentation/pages/home_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
    // 【修改】将 AppBarBloc 的提供者放在这里，管理 AppBar 的事件
    return BlocProvider(
      create: (context) => AppBarBloc(),
      child: Scaffold(
        // 【修改】使用标准的 AppBar，不再使用 CustomAppBar
        appBar: AppBar(
          // 使用在 main.dart 中定义的全局主题
          automaticallyImplyLeading: false, // 不显示返回按钮
          titleSpacing: 16.0,
          title: BlocBuilder<AppBarBloc, AppBarState>(
            builder: (context, state) {
              return Row(
                children: [
                  // 标题
                  Text(
                    '笔记',
                    // 直接使用 AppBarTheme 的样式，保证统一
                    style: Theme.of(context).appBarTheme.titleTextStyle,
                  ),
                  const Spacer(),
                  // 右侧图标按钮
                  IconButton(
                    icon: const Icon(Icons.location_on_outlined),
                    onPressed: () => context.read<AppBarBloc>().add(AppBarLocationPressed(context)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.tag),
                    onPressed: () => context.read<AppBarBloc>().add(AppBarTagPressed(context)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () => context.read<AppBarBloc>().add(AppBarSearchPressed()),
                  ),
                  IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => context.read<AppBarBloc>().add(AppBarMenuPressed()),
                  ),
                ],
              );
            },
          ),
        ),
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
            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }
}