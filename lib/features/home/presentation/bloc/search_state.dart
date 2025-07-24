import 'package:equatable/equatable.dart';
import 'package:record_app/core/utils/search_service.dart';

enum SearchStatus {
  initial,
  loading,
  success,
  empty,
  error,
}

class SearchState extends Equatable {
  final String query;
  final List<SearchResultItem> results;
  final SearchStatus status;
  final String? errorMessage;
  final SearchResultItem? selectedResult;

  const SearchState({
    required this.query,
    required this.results,
    required this.status,
    this.errorMessage,
    this.selectedResult,
  });

  // 初始状态
  const SearchState.initial()
      : query = '',
        results = const [],
        status = SearchStatus.initial,
        errorMessage = null,
        selectedResult = null;

  // 加载中状态
  const SearchState.loading()
      : query = '',
        results = const [],
        status = SearchStatus.loading,
        errorMessage = null,
        selectedResult = null;

  // 搜索成功状态
  const SearchState.success(List<SearchResultItem> results)
      : query = '',
        results = results,
        status = SearchStatus.success,
        errorMessage = null,
        selectedResult = null;

  // 搜索为空状态
  const SearchState.empty()
      : query = '',
        results = const [],
        status = SearchStatus.empty,
        errorMessage = null,
        selectedResult = null;

  // 搜索错误状态
  const SearchState.error(String message)
      : query = '',
        results = const [],
        status = SearchStatus.error,
        errorMessage = message,
        selectedResult = null;

  @override
  List<Object?> get props => [query, results, status, errorMessage, selectedResult];

  SearchState copyWith({
    String? query,
    List<SearchResultItem>? results,
    SearchStatus? status,
    String? errorMessage,
    SearchResultItem? selectedResult,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      selectedResult: selectedResult ?? this.selectedResult,
    );
  }
} 