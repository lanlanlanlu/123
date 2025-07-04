import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

// 事件
abstract class AppBarEvent extends Equatable {
  const AppBarEvent();
  
  @override
  List<Object?> get props => [];
}

class AppBarLocationPressed extends AppBarEvent {}
class AppBarTagPressed extends AppBarEvent {}
class AppBarSearchPressed extends AppBarEvent {}
class AppBarMenuPressed extends AppBarEvent {}

// 状态
class AppBarState extends Equatable {
  final bool isSearchActive;
  
  const AppBarState({
    this.isSearchActive = false,
  });
  
  AppBarState copyWith({
    bool? isSearchActive,
  }) {
    return AppBarState(
      isSearchActive: isSearchActive ?? this.isSearchActive,
    );
  }
  
  @override
  List<Object?> get props => [isSearchActive];
}

// Bloc
class AppBarBloc extends Bloc<AppBarEvent, AppBarState> {
  AppBarBloc() : super(const AppBarState()) {
    on<AppBarLocationPressed>(_onLocationPressed);
    on<AppBarTagPressed>(_onTagPressed);
    on<AppBarSearchPressed>(_onSearchPressed);
    on<AppBarMenuPressed>(_onMenuPressed);
  }
  
  void _onLocationPressed(AppBarLocationPressed event, Emitter<AppBarState> emit) {
    // 处理位置按钮逻辑
    // 暂时只是占位
  }
  
  void _onTagPressed(AppBarTagPressed event, Emitter<AppBarState> emit) {
    // 处理标签按钮逻辑
    // 暂时只是占位
  }
  
  void _onSearchPressed(AppBarSearchPressed event, Emitter<AppBarState> emit) {
    emit(state.copyWith(isSearchActive: !state.isSearchActive));
  }
  
  void _onMenuPressed(AppBarMenuPressed event, Emitter<AppBarState> emit) {
    // 处理菜单按钮逻辑
    // 暂时只是占位
  }
} 