import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题状态类
class ThemeState {
  final ThemeMode themeMode;
  final bool isDynamicColorEnabled;

  const ThemeState({
    required this.themeMode,
    required this.isDynamicColorEnabled,
  });

  /// 创建初始状态
  factory ThemeState.initial() {
    return const ThemeState(
      themeMode: ThemeMode.system,
      isDynamicColorEnabled: true,
    );
  }

  /// 复制并修改状态
  ThemeState copyWith({
    ThemeMode? themeMode,
    bool? isDynamicColorEnabled,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      isDynamicColorEnabled: isDynamicColorEnabled ?? this.isDynamicColorEnabled,
    );
  }
}

/// 主题Cubit，用于管理应用主题
class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit() : super(ThemeState.initial());

  /// 初始化主题设置
  Future<void> initTheme() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 读取主题模式
    final String? themeModeString = prefs.getString('theme_mode');
    ThemeMode themeMode = ThemeMode.system; // 默认为系统模式
    
    if (themeModeString != null) {
      switch (themeModeString) {
        case 'light':
          themeMode = ThemeMode.light;
          break;
        case 'dark':
          themeMode = ThemeMode.dark;
          break;
        default:
          themeMode = ThemeMode.system;
      }
    }
    
    // 读取动态颜色设置
    final bool isDynamicColorEnabled = prefs.getBool('dynamic_color_enabled') ?? true;
    
    // 更新状态
    emit(state.copyWith(
      themeMode: themeMode,
      isDynamicColorEnabled: isDynamicColorEnabled,
    ));
  }

  /// 更改主题模式
  Future<void> changeThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 保存主题模式设置
    String modeString;
    switch (mode) {
      case ThemeMode.light:
        modeString = 'light';
        break;
      case ThemeMode.dark:
        modeString = 'dark';
        break;
      case ThemeMode.system:
      default:
        modeString = 'system';
    }
    
    await prefs.setString('theme_mode', modeString);
    
    // 更新状态
    emit(state.copyWith(themeMode: mode));
  }

  /// 切换动态颜色
  Future<void> toggleDynamicColor(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 保存动态颜色设置
    await prefs.setBool('dynamic_color_enabled', enabled);
    
    // 更新状态
    emit(state.copyWith(isDynamicColorEnabled: enabled));
  }

  /// 获取当前主题模式的字符串表示
  String getCurrentThemeModeString() {
    switch (state.themeMode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
      default:
        return 'system';
    }
  }
} 