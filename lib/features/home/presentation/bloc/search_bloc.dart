import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:record_app/core/utils/search_service.dart';
import 'package:record_app/features/home/presentation/bloc/search_event.dart';
import 'package:record_app/features/home/presentation/bloc/search_state.dart';

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final SearchService _searchService;
  
  // 添加防抖定时器
  Timer? _debounce;
  String _lastQuery = '';
  
  SearchBloc({required SearchService searchService}) 
      : _searchService = searchService,
        super(const SearchState.initial()) {
    on<SearchQueryChanged>(_onSearchQueryChanged);
    on<SearchResultSelected>(_onSearchResultSelected);
    on<SearchCleared>(_onSearchCleared);
    on<_PerformSearch>(_onPerformSearch);
  }
  
  void _onSearchQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) {
    final query = event.query;
    _lastQuery = query;
    
    // 清除旧的防抖定时器
    if (_debounce?.isActive ?? false) {
      _debounce?.cancel();
    }
    
    // 如果查询为空，则返回初始状态
    if (query.isEmpty) {
      emit(const SearchState.initial());
      return;
    }
    
    // 设置搜索中状态
    emit(const SearchState.loading());
    
    // 使用防抖，延迟300ms再触发真正的搜索事件
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!isClosed) {
        add(_PerformSearch(query));
      }
    });
  }
  
  // 新增：执行实际搜索的事件处理函数
  Future<void> _onPerformSearch(
    _PerformSearch event,
    Emitter<SearchState> emit,
  ) async {
    // 如果查询已经改变，不执行搜索
    if (event.query != _lastQuery) {
      return;
    }
    
    try {
      final results = await _searchService.searchAll(event.query);
      if (results.isEmpty) {
        emit(const SearchState.empty());
      } else {
        emit(SearchState.success(results));
      }
    } catch (error) {
      emit(SearchState.error('搜索出错：$error'));
    }
  }
  
  void _onSearchResultSelected(
    SearchResultSelected event,
    Emitter<SearchState> emit,
  ) {
    // 当用户选择某个搜索结果时的处理
    // 这里只是修改状态，具体的导航逻辑会在UI层处理
    emit(state.copyWith(selectedResult: event.result));
  }
  
  void _onSearchCleared(
    SearchCleared event,
    Emitter<SearchState> emit,
  ) {
    // 清除搜索结果，回到初始状态
    emit(const SearchState.initial());
  }
  
  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}

// 内部事件类，用于实际执行搜索
class _PerformSearch extends SearchEvent {
  final String query;
  
  const _PerformSearch(this.query);
  
  @override
  List<Object?> get props => [query];
} 