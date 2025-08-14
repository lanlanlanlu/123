import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:record_app/data/database/database.dart';
import 'package:record_app/data/repository/index.dart';
import 'package:record_app/features/home/presentation/bloc/home_event.dart';
import 'package:record_app/features/home/presentation/bloc/home_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final NotesRepository _notesRepository;
  
  // 保存笔记流订阅，以便在BLoC销毁时取消订阅
  StreamSubscription? _notesSubscription;
  
  // 当前的排序设置
  NoteSortType _currentSortType = NoteSortType.updatedAt;
  SortOrder _currentSortOrder = SortOrder.descending;
  
  // 排序设置的持久化键
  static const String _sortTypeKey = 'note_sort_type';
  static const String _sortOrderKey = 'note_sort_order';

  HomeBloc({required NotesRepository notesRepository}) 
      : _notesRepository = notesRepository,
        super(const HomeInitial()) {
    on<HomeLoadNotes>(_onLoadNotes);
    on<HomeLoadNotesByLocation>(_onLoadNotesByLocation);
    on<HomeNoteDeleted>(_onNoteDeleted);
    on<HomeNoteRestored>(_onNoteRestored);
    on<HomeNotesUpdated>(_onNotesUpdated);
    on<HomeNotesError>(_onNotesError);
    on<HomeSortNotesChanged>(_onSortChanged);
    
    // 初始化时加载保存的排序设置
    _loadSavedSortSettings().then((_) {
      // 加载完成后，如果还没有触发其他事件，触发加载笔记事件
      if (state is HomeInitial) {
        add(const HomeLoadNotes());
      }
    });
  }
  
  /// 加载保存的排序设置
  Future<void> _loadSavedSortSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 加载排序类型
      final sortTypeIndex = prefs.getInt(_sortTypeKey);
      if (sortTypeIndex != null) {
        _currentSortType = NoteSortType.values[sortTypeIndex];
      }
      
      // 加载排序顺序
      final sortOrderIndex = prefs.getInt(_sortOrderKey);
      if (sortOrderIndex != null) {
        _currentSortOrder = SortOrder.values[sortOrderIndex];
      }
    } catch (e) {
      // 如果加载失败，使用默认设置
      print('加载排序设置失败: $e');
    }
  }
  
  /// 保存排序设置到持久化存储
  Future<void> _saveSortSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 保存排序类型和顺序的索引值
      await prefs.setInt(_sortTypeKey, _currentSortType.index);
      await prefs.setInt(_sortOrderKey, _currentSortOrder.index);
    } catch (e) {
      print('保存排序设置失败: $e');
    }
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
      .listen(
        (notes) {
          // 直接对笔记进行排序
          final sortedNotes = _sortNotes(notes, _currentSortType, _currentSortOrder);
          add(HomeNotesUpdated(sortedNotes));
        },
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
        .listen(
          (notes) {
            // 直接对笔记进行排序
            final sortedNotes = _sortNotes(notes, _currentSortType, _currentSortOrder);
            add(HomeNotesUpdated(sortedNotes));
          },
          onError: (error) => add(HomeNotesError(error.toString())),
        );
    } catch (e) {
      emit(HomeLoadFailure('加载位置笔记失败: ${e.toString()}'));
    }
  }

  /// 处理笔记更新事件（内部使用，不暴露给UI）
  Future<void> _onNotesUpdated(HomeNotesUpdated event, Emitter<HomeState> emit) async {
    emit(HomeLoadSuccess(
      event.notes, 
      sortType: _currentSortType,
      sortOrder: _currentSortOrder,
    ));
  }

  /// 处理笔记错误事件（内部使用，不暴露给UI）
  Future<void> _onNotesError(HomeNotesError event, Emitter<HomeState> emit) async {
    emit(HomeLoadFailure(event.message));
  }

  /// 处理删除笔记事件
  Future<void> _onNoteDeleted(HomeNoteDeleted event, Emitter<HomeState> emit) async {
    try {
      await _notesRepository.softDeleteNote(event.id);
      // 使用常量字符串，方便后续全球化
      emit(const HomeOperationSuccess('NOTE_DELETED'));
    } catch (e) {
      emit(HomeLoadFailure('ERROR_DELETE_NOTE: ${e.toString()}'));
    }
  }

  /// 处理还原笔记事件
  Future<void> _onNoteRestored(HomeNoteRestored event, Emitter<HomeState> emit) async {
    try {
      await _notesRepository.restoreNote(event.id);
      // 使用常量字符串，方便后续全球化
      emit(const HomeOperationSuccess('NOTE_RESTORED'));
    } catch (e) {
      emit(HomeLoadFailure('ERROR_RESTORE_NOTE: ${e.toString()}'));
    }
  }
  
  /// 处理排序变化事件
  Future<void> _onSortChanged(HomeSortNotesChanged event, Emitter<HomeState> emit) async {
    // 更新当前排序设置
    _currentSortType = event.sortType;
    _currentSortOrder = event.sortOrder;
    
    // 保存排序设置到持久化存储
    await _saveSortSettings();
    
    // 如果当前已经加载了笔记，需要重新排序
    if (state is HomeLoadSuccess) {
      final currentState = state as HomeLoadSuccess;
      final sortedNotes = _sortNotes(
        currentState.notes,
        _currentSortType,
        _currentSortOrder,
      );
      
      // 使用新的排序设置创建新状态
      emit(HomeLoadSuccess(
        sortedNotes,
        sortType: _currentSortType,
        sortOrder: _currentSortOrder,
      ));
    } else {
      // 如果还没有加载笔记，需要重新加载
      add(const HomeLoadNotes());
    }
  }
  
  /// 根据排序规则对笔记列表进行排序
  List<Note> _sortNotes(List<Note> notes, NoteSortType sortType, SortOrder sortOrder) {
    // 创建一个新列表，不修改原列表
    final sortedNotes = List<Note>.from(notes);
    
    // 根据排序类型选择不同的比较函数
    switch (sortType) {
      case NoteSortType.updatedAt:
        sortedNotes.sort((a, b) {
          final result = a.updatedAt.compareTo(b.updatedAt);
          return sortOrder == SortOrder.descending ? -result : result;
        });
        break;
      case NoteSortType.createdAt:
        sortedNotes.sort((a, b) {
          final result = a.createdAt.compareTo(b.createdAt);
          return sortOrder == SortOrder.descending ? -result : result;
        });
        break;
    }
    
    return sortedNotes;
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