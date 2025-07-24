import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:record_app/data/repository/notes_repository.dart';
import 'package:record_app/data/repository/tags_repository.dart';
import 'settings_stats_event.dart';
import 'settings_stats_state.dart';

// BLoC实现
class SettingsStatsBloc extends Bloc<SettingsStatsEvent, SettingsStatsState> {
  final NotesRepository notesRepository;
  final TagsRepository tagsRepository;

  SettingsStatsBloc({
    required this.notesRepository,
    required this.tagsRepository,
  }) : super(const SettingsStatsState()) {
    on<LoadStatsData>(_onLoadStatsData);
  }

  Future<void> _onLoadStatsData(
    LoadStatsData event,
    Emitter<SettingsStatsState> emit,
  ) async {
    try {
      emit(state.copyWith(isLoading: true, error: null));
      
      // 获取所有笔记
      final notes = await notesRepository.getAllNotes();
      
      // 1. 计算笔记总数
      final noteCount = notes.length;
      
      // 2. 计算总字数
      int characterCount = 0;
      
      // 3. 记录不同的写作日期
      final Set<String> uniqueDays = {};
      
      // 处理每个笔记
      for (final note in notes) {
        // 从笔记内容中提取纯文本
        try {
          // 解析JSON内容以提取文本
          final content = note.content;
          if (content.isNotEmpty) {
            try {
              final jsonContent = json.decode(content) as List;
              for (var op in jsonContent) {
                if (op is Map && op.containsKey('insert') && op['insert'] is String) {
                  characterCount += op['insert'].toString().length;
                }
              }
            } catch (_) {
              // 如果解析失败，直接加上整个内容长度
              characterCount += content.length;
            }
          }
          
          // 记录日期 (格式: yyyy-MM-dd)
          final dateStr = "${note.createdAt.year}-${note.createdAt.month.toString().padLeft(2, '0')}-${note.createdAt.day.toString().padLeft(2, '0')}";
          uniqueDays.add(dateStr);
        } catch (e) {
          // 忽略单个笔记的错误
          continue;
        }
      }
      
      // 获取唯一日期数量
      final dayCount = uniqueDays.length;
      
      // 4. 获取标签总数
      final tags = await tagsRepository.watchAllTags().first;
      final tagCount = tags.length;
      
      // 发送最终状态
      emit(state.copyWith(
        noteCount: noteCount,
        characterCount: characterCount,
        dayCount: dayCount,
        tagCount: tagCount,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Failed to load statistics: ${e.toString()}',
      ));
    }
  }
} 