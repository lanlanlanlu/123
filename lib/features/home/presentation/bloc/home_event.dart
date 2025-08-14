import 'package:equatable/equatable.dart';

/// 笔记排序类型
enum NoteSortType {
  /// 按更新时间
  updatedAt,
  /// 按创建时间
  createdAt,
}

/// 排序顺序
enum SortOrder {
  /// 降序（从新到旧）
  descending,
  /// 升序（从旧到新）
  ascending,
}

/// Home页面的所有事件基类
abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

/// 初始化事件，加载所有笔记
class HomeLoadNotes extends HomeEvent {
  const HomeLoadNotes();
}

/// 加载特定位置的笔记事件
class HomeLoadNotesByLocation extends HomeEvent {
  final String location;

  const HomeLoadNotesByLocation(this.location);

  @override
  List<Object?> get props => [location];
}

/// 删除笔记事件
class HomeNoteDeleted extends HomeEvent {
  final int id;

  const HomeNoteDeleted(this.id);

  @override
  List<Object?> get props => [id];
}

/// 还原已删除笔记事件
class HomeNoteRestored extends HomeEvent {
  final int id;

  const HomeNoteRestored(this.id);

  @override
  List<Object?> get props => [id];
}

/// 改变笔记排序方式
class HomeSortNotesChanged extends HomeEvent {
  final NoteSortType sortType;
  final SortOrder sortOrder;
  
  const HomeSortNotesChanged({
    required this.sortType,
    required this.sortOrder,
  });
  
  @override
  List<Object?> get props => [sortType, sortOrder];
} 