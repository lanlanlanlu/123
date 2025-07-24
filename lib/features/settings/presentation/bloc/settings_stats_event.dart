import 'package:equatable/equatable.dart';

// 统计数据事件定义
abstract class SettingsStatsEvent extends Equatable {
  const SettingsStatsEvent();

  @override
  List<Object?> get props => [];
}

// 加载统计数据事件
class LoadStatsData extends SettingsStatsEvent {
  const LoadStatsData();
} 