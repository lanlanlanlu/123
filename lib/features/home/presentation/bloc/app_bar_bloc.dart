import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:record_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:record_app/features/home/presentation/bloc/home_event.dart';
import 'package:record_app/features/home/presentation/pages/location_list_page.dart';
import 'package:record_app/features/tags/presentation/pages/tag_categories_page.dart';

// 事件
abstract class AppBarEvent extends Equatable {
  const AppBarEvent();
  
  @override
  List<Object?> get props => [];
}

class AppBarLocationPressed extends AppBarEvent {
  final BuildContext context;
  
  const AppBarLocationPressed(this.context);
  
  @override
  List<Object?> get props => [context];
}

class AppBarTagPressed extends AppBarEvent {
  final BuildContext context;
  
  const AppBarTagPressed(this.context);
  
  @override
  List<Object?> get props => [context];
}

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
  
  void _onLocationPressed(AppBarLocationPressed event, Emitter<AppBarState> emit) async {
    // 导航到位置列表页面，并等待返回结果
    final result = await Navigator.of(event.context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const LocationListPage(),
      ),
    );
    
    // 如果返回结果为true，表示位置已被删除，需要刷新主页
    if (result == true) {
      // 刷新主页
      if (event.context.mounted) {
        try {
          // 先尝试使用context.read获取HomeBloc
          try {
            final bloc = event.context.read<HomeBloc>();
            bloc.add(HomeLoadNotes());
          } catch (e) {
            debugPrint('无法通过context.read获取HomeBloc: $e');
            
            // 如果无法获取，则返回到主页并刷新
            final navigatorState = Navigator.of(event.context);
            navigatorState.popUntil((route) => route.isFirst);
            
            // 等待一帧，确保回到了主页
            await Future.delayed(const Duration(milliseconds: 100));
            
            if (event.context.mounted) {
              try {
                final bloc = event.context.read<HomeBloc>();
                bloc.add(HomeLoadNotes());
              } catch (e) {
                debugPrint('无法刷新主页: $e');
              }
            }
          }
        } catch (e) {
          debugPrint('无法刷新主页: $e');
        }
      }
    }
  }
  
  void _onTagPressed(AppBarTagPressed event, Emitter<AppBarState> emit) async {
    // 导航到标签分类页面，并等待返回结果
    final result = await Navigator.of(event.context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const TagCategoriesPage(),
      ),
    );
    
    // 如果返回结果为true，表示标签已被删除或修改，需要刷新主页
    if (result == true) {
      // 刷新主页
      if (event.context.mounted) {
        try {
          // 先尝试使用context.read获取HomeBloc
          try {
            final bloc = event.context.read<HomeBloc>();
            bloc.add(HomeLoadNotes());
          } catch (e) {
            debugPrint('无法通过context.read获取HomeBloc: $e');
            
            // 如果无法获取，则返回到主页并刷新
            final navigatorState = Navigator.of(event.context);
            navigatorState.popUntil((route) => route.isFirst);
            
            // 等待一帧，确保回到了主页
            await Future.delayed(const Duration(milliseconds: 100));
            
            if (event.context.mounted) {
              try {
                final bloc = event.context.read<HomeBloc>();
                bloc.add(HomeLoadNotes());
              } catch (e) {
                debugPrint('无法刷新主页: $e');
              }
            }
          }
        } catch (e) {
          debugPrint('无法刷新主页: $e');
        }
      }
    }
  }
  
  void _onSearchPressed(AppBarSearchPressed event, Emitter<AppBarState> emit) {
    emit(state.copyWith(isSearchActive: !state.isSearchActive));
  }
  
  void _onMenuPressed(AppBarMenuPressed event, Emitter<AppBarState> emit) {
    // 处理菜单按钮逻辑
    // 暂时只是占位
  }
} 