import 'package:equatable/equatable.dart';

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