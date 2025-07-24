import 'package:equatable/equatable.dart';
import 'package:record_app/core/utils/search_service.dart';

abstract class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

/// 搜索查询变更事件
class SearchQueryChanged extends SearchEvent {
  final String query;

  const SearchQueryChanged(this.query);

  @override
  List<Object?> get props => [query];
}

/// 搜索结果选中事件
class SearchResultSelected extends SearchEvent {
  final SearchResultItem result;

  const SearchResultSelected(this.result);

  @override
  List<Object?> get props => [result];
}

/// 搜索清除事件
class SearchCleared extends SearchEvent {
  const SearchCleared();
} 