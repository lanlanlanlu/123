import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:record_app/data/repository/notes_repository.dart';

// 事件定义
abstract class SettingsHeatMapEvent extends Equatable {
  const SettingsHeatMapEvent();

  @override
  List<Object?> get props => [];
}

// 加载热力图数据事件
class LoadHeatMapData extends SettingsHeatMapEvent {
  const LoadHeatMapData();
}

// 状态定义
class SettingsHeatMapState extends Equatable {
  final Map<DateTime, int> heatMapData;
  final bool isLoading;
  final String? error;

  const SettingsHeatMapState({
    this.heatMapData = const {},
    this.isLoading = false,
    this.error,
  });

  SettingsHeatMapState copyWith({
    Map<DateTime, int>? heatMapData,
    bool? isLoading,
    String? error,
  }) {
    return SettingsHeatMapState(
      heatMapData: heatMapData ?? this.heatMapData,
      isLoading: isLoading ?? this.isLoading,
      error: error != null ? error : this.error,
    );
  }

  @override
  List<Object?> get props => [heatMapData, isLoading, error];
}

// Bloc实现
class SettingsHeatMapBloc extends Bloc<SettingsHeatMapEvent, SettingsHeatMapState> {
  final NotesRepository notesRepository;

  SettingsHeatMapBloc({required this.notesRepository}) 
      : super(const SettingsHeatMapState()) {
    on<LoadHeatMapData>(_onLoadHeatMapData);
  }

  Future<void> _onLoadHeatMapData(
    LoadHeatMapData event,
    Emitter<SettingsHeatMapState> emit,
  ) async {
    try {
      emit(state.copyWith(isLoading: true, error: null));
      
      // 获取过去一年的笔记创建日期数据
      final DateTime now = DateTime.now();
      final DateTime oneYearAgo = DateTime(now.year - 1, now.month, now.day);
      
      final notes = await notesRepository.getAllNotes();
      
      // 统计每天的笔记数量
      final Map<DateTime, int> heatMapData = {};
      
      for (final note in notes) {
        // 只统计过去一年内的笔记
        if (note.createdAt.isAfter(oneYearAgo)) {
          // 使用日期（年月日）作为键，忽略时间部分
          final dateKey = DateTime(
            note.createdAt.year,
            note.createdAt.month,
            note.createdAt.day,
          );
          
          if (heatMapData.containsKey(dateKey)) {
            heatMapData[dateKey] = heatMapData[dateKey]! + 1;
          } else {
            heatMapData[dateKey] = 1;
          }
        }
      }
      
      emit(state.copyWith(
        heatMapData: heatMapData,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: '加载热力图数据失败: ${e.toString()}',
      ));
    }
  }
} 