import 'package:equatable/equatable.dart';

// 统计数据状态定义
class SettingsStatsState extends Equatable {
  final int noteCount;     // 笔记总数
  final int characterCount; // 总字数
  final int dayCount;      // 写作天数
  final int tagCount;      // 标签总数
  final bool isLoading;
  final String? error;

  const SettingsStatsState({
    this.noteCount = 0,
    this.characterCount = 0,
    this.dayCount = 0,
    this.tagCount = 0,
    this.isLoading = false,
    this.error,
  });

  SettingsStatsState copyWith({
    int? noteCount,
    int? characterCount,
    int? dayCount,
    int? tagCount,
    bool? isLoading,
    String? error,
  }) {
    return SettingsStatsState(
      noteCount: noteCount ?? this.noteCount,
      characterCount: characterCount ?? this.characterCount,
      dayCount: dayCount ?? this.dayCount,
      tagCount: tagCount ?? this.tagCount,
      isLoading: isLoading ?? this.isLoading,
      error: error != null ? error : this.error,
    );
  }

  @override
  List<Object?> get props => [noteCount, characterCount, dayCount, tagCount, isLoading, error];
} 