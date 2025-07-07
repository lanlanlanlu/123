import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:record_app/data/database/database.dart';
import 'package:record_app/data/repository/index.dart';
import 'package:record_app/features/home/presentation/bloc/home_event.dart';
import 'package:record_app/features/home/presentation/bloc/home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final NotesRepository _notesRepository;
  
  // 保存笔记流订阅，以便在BLoC销毁时取消订阅
  StreamSubscription? _notesSubscription;

  HomeBloc({required NotesRepository notesRepository}) 
      : _notesRepository = notesRepository,
        super(const HomeInitial()) {
    on<HomeLoadNotes>(_onLoadNotes);
    on<HomeLoadNotesByLocation>(_onLoadNotesByLocation);
    on<HomeNoteDeleted>(_onNoteDeleted);
    on<HomeNoteRestored>(_onNoteRestored);
    on<HomeNotesUpdated>(_onNotesUpdated);
    on<HomeNotesError>(_onNotesError);
  }

  /// 处理加载笔记事件
  Future<void> _onLoadNotes(HomeLoadNotes event, Emitter<HomeState> emit) async {
    emit(const HomeLoading());
    
    // 取消之前的订阅（如果有）
    await _notesSubscription?.cancel();
    
    // 短暂延迟后订阅笔记流，给UI渲染一些时间
    await Future.delayed(const Duration(milliseconds: 50));
    
    // 使用批量加载策略订阅笔记流
    _notesSubscription = _notesRepository.watchAllNotes()
      .asyncMap((notes) async {
        // 如果笔记数量很多，考虑分批加载或限制数量
        if (notes.length > 100) {
          return notes.take(100).toList();
        }
        return notes;
      })
      .listen(
        (notes) => add(HomeNotesUpdated(notes)),
        onError: (error) => add(HomeNotesError(error.toString())),
      );
  }

  /// 处理加载特定位置笔记事件
  Future<void> _onLoadNotesByLocation(HomeLoadNotesByLocation event, Emitter<HomeState> emit) async {
    emit(const HomeLoading());
    
    // 取消之前的订阅（如果有）
    await _notesSubscription?.cancel();
    
    try {
      // 短暂延迟后订阅笔记流，给UI渲染一些时间
      await Future.delayed(const Duration(milliseconds: 50));
      
      // 使用批量加载策略订阅特定位置的笔记流
      _notesSubscription = _notesRepository.watchNotesByLocation(event.location)
        .asyncMap((notes) async {
          // 如果笔记数量很多，考虑分批加载或限制数量
          if (notes.length > 100) {
            return notes.take(100).toList();
          }
          return notes;
        })
        .listen(
          (notes) => add(HomeNotesUpdated(notes)),
          onError: (error) => add(HomeNotesError(error.toString())),
        );
    } catch (e) {
      emit(HomeLoadFailure('加载位置笔记失败: ${e.toString()}'));
    }
  }

  /// 处理笔记更新事件（内部使用，不暴露给UI）
  Future<void> _onNotesUpdated(HomeNotesUpdated event, Emitter<HomeState> emit) async {
    emit(HomeLoadSuccess(event.notes));
  }

  /// 处理笔记错误事件（内部使用，不暴露给UI）
  Future<void> _onNotesError(HomeNotesError event, Emitter<HomeState> emit) async {
    emit(HomeLoadFailure(event.message));
  }

  /// 处理删除笔记事件
  Future<void> _onNoteDeleted(HomeNoteDeleted event, Emitter<HomeState> emit) async {
    try {
      await _notesRepository.softDeleteNote(event.id);
      emit(const HomeOperationSuccess('笔记已删除'));
    } catch (e) {
      emit(HomeLoadFailure('删除笔记失败: ${e.toString()}'));
    }
  }

  /// 处理还原笔记事件
  Future<void> _onNoteRestored(HomeNoteRestored event, Emitter<HomeState> emit) async {
    try {
      await _notesRepository.restoreNote(event.id);
      emit(const HomeOperationSuccess('笔记已还原'));
    } catch (e) {
      emit(HomeLoadFailure('还原笔记失败: ${e.toString()}'));
    }
  }

  @override
  Future<void> close() {
    _notesSubscription?.cancel();
    return super.close();
  }
}

/// 内部事件: 笔记数据已更新
class HomeNotesUpdated extends HomeEvent {
  final List<Note> notes;

  const HomeNotesUpdated(this.notes);

  @override
  List<Object?> get props => [notes];
}

/// 内部事件: 笔记数据错误
class HomeNotesError extends HomeEvent {
  final String message;

  const HomeNotesError(this.message);

  @override
  List<Object?> get props => [message];
} 