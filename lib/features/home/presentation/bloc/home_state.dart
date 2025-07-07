import 'package:equatable/equatable.dart';
import 'package:record_app/data/database/database.dart';

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
  
  const HomeLoadSuccess(this.notes);
  
  @override
  List<Object?> get props => [notes];
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