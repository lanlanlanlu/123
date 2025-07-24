import 'package:equatable/equatable.dart';

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