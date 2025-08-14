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
import 'package:record_app/features/home/presentation/widgets/note_list.dart';

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
  const HomeView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // 【修改】移除了 Scaffold，只返回 body 内容
    return BlocConsumer<HomeBloc, HomeState>(
      listener: (context, state) {
        // 处理操作成功消息
        if (state is HomeOperationSuccess) {
          // 根据消息类型获取本地化字符串
          String localizedMessage;
          switch (state.message) {
            case 'NOTE_DELETED':
              localizedMessage = s.noteDeleted;
              break;
            case 'NOTE_RESTORED':
              localizedMessage = s.noteDetailRestore;
              break;
            default:
              localizedMessage = state.message;
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizedMessage)),
          );
          
          // 操作成功后重新加载笔记
          context.read<HomeBloc>().add(const HomeLoadNotes());
        }
      },
      builder: (context, state) {
        // 调试输出当前排序状态
        if (state is HomeLoadSuccess) {
          print('当前排序状态: 类型=${state.sortType}, 顺序=${state.sortOrder}');
        }
        
        if (state is HomeLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is HomeLoadSuccess) {
          if (state.notes.isEmpty) {
            return const EmptyNotesView();
          }
          return NoteList(notes: state.notes);
        } else if (state is HomeLoadFailure) {
          // 根据错误消息类型获取本地化字符串
          String localizedError;
          if (state.message.startsWith('ERROR_DELETE_NOTE')) {
            localizedError = s.noteDetailDeleteConfirmation;
          } else if (state.message.startsWith('ERROR_RESTORE_NOTE')) {
            localizedError = '${s.noteDetailRestore} ${s.aiChatError}';
          } else {
            localizedError = state.message;
          }
          return Center(child: Text(localizedError));
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}