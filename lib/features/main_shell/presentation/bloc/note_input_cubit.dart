import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:drift/drift.dart';
import 'package:record/data/database/database.dart';
import 'package:record/data/repository/index.dart';

// 笔记输入状态
enum NoteInputStatus {
  idle,
  saving,
  success,
  failure
}

// 笔记输入状态类
class NoteInputState extends Equatable {
  final String text;
  final NoteInputStatus status;
  final String? errorMessage;

  const NoteInputState({
    this.text = '',
    this.status = NoteInputStatus.idle,
    this.errorMessage,
  });

  NoteInputState copyWith({
    String? text,
    NoteInputStatus? status,
    String? errorMessage,
  }) {
    return NoteInputState(
      text: text ?? this.text,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [text, status, errorMessage];
}

// 笔记输入Cubit
class NoteInputCubit extends Cubit<NoteInputState> {
  final NotesRepository _notesRepository;

  NoteInputCubit({required NotesRepository notesRepository})
      : _notesRepository = notesRepository,
        super(const NoteInputState());

  // 更新文本
  void updateText(String text) {
    emit(state.copyWith(text: text));
  }

  // 保存笔记
  Future<void> saveNote() async {
    if (state.text.trim().isEmpty) {
      return;
    }

    emit(state.copyWith(status: NoteInputStatus.saving));

    try {
      final now = DateTime.now();
      final text = state.text;
      
      // 使用NotesRepository的方法解析和处理文本
      final tagNames = _notesRepository.parseTagsFromText(text);
      final locations = _notesRepository.parseLocationsFromText(text);
      
      // 提取位置信息
      String? locationInfo;
      if (locations.isNotEmpty) {
        locationInfo = locations.last;
      }
      
      // 清理内容，移除标签和位置标记
      String cleanContent = _notesRepository.cleanText(text);
      
      // 提取标题和内容，从第一行获取标题，剩余部分作为内容
      String title = '';
      String content = cleanContent;
      
      if (cleanContent.contains('\n')) {
        // 如果有换行符，使用第一行作为标题，其余内容作为正文
        final parts = cleanContent.split('\n');
        title = parts.first;
        // 移除第一行（标题）后剩余的内容作为正文
        content = parts.sublist(1).join('\n').trim();
      } else {
        // 如果没有换行符，全部内容作为标题，内容为空
        title = cleanContent;
        content = '';
      }
      
      // 创建NotesCompanion对象
      final note = NotesCompanion.insert(
        title: title,
        content: content, // 内容部分不再包含标题
        locationInfo: Value(locationInfo),
        createdAt: Value(now),
        updatedAt: Value(now),
      );
      
      // 插入笔记
      final noteId = await _notesRepository.insertNote(note);
      
      // 处理标签
      for (final tagName in tagNames) {
        await _notesRepository.addTagToNote(noteId, tagName);
      }
      
      // 处理位置
      if (locationInfo != null && locationInfo.isNotEmpty) {
        await _notesRepository.addLocationToNote(noteId, locationInfo, now);
      }
      
      emit(state.copyWith(
        status: NoteInputStatus.success,
        text: '',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: NoteInputStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  // 重置状态
  void reset() {
    emit(const NoteInputState());
  }
} 