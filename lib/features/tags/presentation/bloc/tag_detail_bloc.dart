import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:record/data/database/database.dart';
import 'package:record/data/repository/index.dart';

// Events
abstract class TagDetailEvent extends Equatable {
  const TagDetailEvent();

  @override
  List<Object?> get props => [];
}

class TagDetailLoadNotes extends TagDetailEvent {
  final String tagName;

  const TagDetailLoadNotes(this.tagName);

  @override
  List<Object?> get props => [tagName];
}

class TagDetailLoadNotesByYear extends TagDetailEvent {
  final String year;

  const TagDetailLoadNotesByYear(this.year);

  @override
  List<Object?> get props => [year];
}

class TagDetailNoteDeleted extends TagDetailEvent {
  final int noteId;

  const TagDetailNoteDeleted(this.noteId);

  @override
  List<Object?> get props => [noteId];
}

class TagDetailNoteRestored extends TagDetailEvent {
  final int noteId;

  const TagDetailNoteRestored(this.noteId);

  @override
  List<Object?> get props => [noteId];
}

// States
abstract class TagDetailState extends Equatable {
  const TagDetailState();

  @override
  List<Object?> get props => [];
}

class TagDetailInitial extends TagDetailState {
  const TagDetailInitial();
}

class TagDetailLoading extends TagDetailState {
  const TagDetailLoading();
}

class TagDetailLoaded extends TagDetailState {
  final List<Note> notes;
  final String tagName;

  const TagDetailLoaded({required this.notes, required this.tagName});

  @override
  List<Object?> get props => [notes, tagName];
}

class TagDetailError extends TagDetailState {
  final String message;

  const TagDetailError(this.message);

  @override
  List<Object?> get props => [message];
}

class TagDetailOperationSuccess extends TagDetailState {
  final String message;

  const TagDetailOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class TagDetailBloc extends Bloc<TagDetailEvent, TagDetailState> {
  final NotesRepository _notesRepository;
  StreamSubscription? _notesSubscription;
  String _currentTagName = '';
  bool _isYearTag = false;

  TagDetailBloc({required NotesRepository notesRepository})
      : _notesRepository = notesRepository,
        super(const TagDetailInitial()) {
    on<TagDetailLoadNotes>(_onLoadNotes);
    on<TagDetailLoadNotesByYear>(_onLoadNotesByYear);
    on<TagDetailNoteDeleted>(_onNoteDeleted);
    on<TagDetailNoteRestored>(_onNoteRestored);
    on<_TagDetailNotesUpdated>(_onNotesUpdated);
    on<_TagDetailError>(_onError);
  }

  Future<void> _onLoadNotes(TagDetailLoadNotes event, Emitter<TagDetailState> emit) async {
    emit(const TagDetailLoading());
    _currentTagName = event.tagName;
    _isYearTag = false;

    await _notesSubscription?.cancel();

    _notesSubscription = _notesRepository.watchNotesByTagName(event.tagName).listen(
      (notes) => add(_TagDetailNotesUpdated(notes: notes, tagName: event.tagName)),
      onError: (error) => add(_TagDetailError(error.toString())),
    );
  }

  Future<void> _onLoadNotesByYear(TagDetailLoadNotesByYear event, Emitter<TagDetailState> emit) async {
    emit(const TagDetailLoading());
    _currentTagName = event.year;
    _isYearTag = true;

    await _notesSubscription?.cancel();

    try {
      // 使用自定义SQL查询获取指定年份的笔记
      final year = event.year;
      
      // 创建自定义查询
      final query = _notesRepository.watchNotesByYear(year);
      
      // 订阅查询结果
      _notesSubscription = query.listen(
        (notes) => add(_TagDetailNotesUpdated(notes: notes, tagName: year)),
        onError: (error) => add(_TagDetailError('获取${year}年笔记失败: $error')),
      );
    } catch (e) {
      emit(TagDetailError('加载${event.year}年笔记失败: $e'));
    }
  }

  Future<void> _onNoteDeleted(TagDetailNoteDeleted event, Emitter<TagDetailState> emit) async {
    try {
      await _notesRepository.softDeleteNote(event.noteId);
      emit(const TagDetailOperationSuccess('笔记已删除'));
    } catch (e) {
      emit(TagDetailError('删除笔记失败: $e'));
    }
  }

  Future<void> _onNoteRestored(TagDetailNoteRestored event, Emitter<TagDetailState> emit) async {
    try {
      await _notesRepository.restoreNote(event.noteId);
      emit(const TagDetailOperationSuccess('笔记已恢复'));
    } catch (e) {
      emit(TagDetailError('恢复笔记失败: $e'));
    }
  }

  Future<void> _onNotesUpdated(_TagDetailNotesUpdated event, Emitter<TagDetailState> emit) async {
    emit(TagDetailLoaded(notes: event.notes, tagName: event.tagName));
  }

  Future<void> _onError(_TagDetailError event, Emitter<TagDetailState> emit) async {
    emit(TagDetailError(event.message));
  }

  @override
  Future<void> close() {
    _notesSubscription?.cancel();
    return super.close();
  }
}

// Internal Events
class _TagDetailNotesUpdated extends TagDetailEvent {
  final List<Note> notes;
  final String tagName;

  const _TagDetailNotesUpdated({required this.notes, required this.tagName});

  @override
  List<Object?> get props => [notes, tagName];
}

class _TagDetailError extends TagDetailEvent {
  final String message;

  const _TagDetailError(this.message);

  @override
  List<Object?> get props => [message];
} 