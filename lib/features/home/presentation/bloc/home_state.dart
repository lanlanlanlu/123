import 'package:equatable/equatable.dart';
import 'package:record_app/data/database/database.dart';
import 'package:record_app/features/home/presentation/bloc/home_event.dart';

/// Home页面的所有状态基类
abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object?> get props => [];
}

/// 初始状态
class HomeInitial extends HomeState {
  const HomeInitial();
}

/// 加载中状态
class HomeLoading extends HomeState {
  const HomeLoading();
}

/// 加载成功状态
class HomeLoadSuccess extends HomeState {
  final List<Note> notes;
  final NoteSortType sortType;
  final SortOrder sortOrder;
  
  const HomeLoadSuccess(
    this.notes, {
    this.sortType = NoteSortType.updatedAt,
    this.sortOrder = SortOrder.descending,
  });
  
  @override
  List<Object?> get props => [notes, sortType, sortOrder];
  
  /// 创建一个复制但使用新排序参数的状态
  HomeLoadSuccess copyWithSort({
    NoteSortType? sortType,
    SortOrder? sortOrder,
  }) {
    return HomeLoadSuccess(
      notes,
      sortType: sortType ?? this.sortType,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
  
  /// 创建一个新状态，带有排序后的笔记列表
  HomeLoadSuccess copyWithSortedNotes(List<Note> sortedNotes) {
    return HomeLoadSuccess(
      sortedNotes,
      sortType: sortType,
      sortOrder: sortOrder,
    );
  }
}

/// 加载失败状态
class HomeLoadFailure extends HomeState {
  final String message;
  
  const HomeLoadFailure(this.message);
  
  @override
  List<Object?> get props => [message];
}

/// 操作成功状态（例如删除笔记成功）
class HomeOperationSuccess extends HomeState {
  final String message;
  
  const HomeOperationSuccess(this.message);
  
  @override
  List<Object?> get props => [message];
} 