import 'package:equatable/equatable.dart';

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