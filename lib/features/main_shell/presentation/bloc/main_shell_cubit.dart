import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 草稿键值常量
const String DRAFT_KEY = 'note_draft';

/// MainShell的状态
class MainShellState {
  final int selectedIndex;
  final String? draftText;
  final bool isInputBoxVisible;
  
  const MainShellState({
    this.selectedIndex = 0,
    this.draftText,
    this.isInputBoxVisible = false,
  });
  
  /// 创建一个副本，但更新某些字段
  MainShellState copyWith({
    int? selectedIndex,
    String? draftText,
    bool? isInputBoxVisible,
    bool clearDraft = false,
  }) {
    return MainShellState(
      selectedIndex: selectedIndex ?? this.selectedIndex,
      draftText: clearDraft ? null : (draftText ?? this.draftText),
      isInputBoxVisible: isInputBoxVisible ?? this.isInputBoxVisible,
    );
  }
}

/// MainShell的Cubit
class MainShellCubit extends Cubit<MainShellState> {
  MainShellCubit() : super(const MainShellState()) {
    loadDraft();
  }
  
  /// 加载草稿内容
  Future<void> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draftText = prefs.getString(DRAFT_KEY);
    emit(state.copyWith(draftText: draftText));
  }
  
  /// 保存草稿内容
  Future<void> saveDraft(String text) async {
    final prefs = await SharedPreferences.getInstance();
    if (text.trim().isNotEmpty) {
      await prefs.setString(DRAFT_KEY, text);
      emit(state.copyWith(draftText: text));
    } else {
      await prefs.remove(DRAFT_KEY);
      emit(state.copyWith(clearDraft: true));
    }
  }
  
  /// 切换到指定的导航索引
  void changeIndex(int index) {
    emit(state.copyWith(selectedIndex: index));
  }
  
  /// 显示输入框
  void showInputBox() {
    emit(state.copyWith(isInputBoxVisible: true));
  }
  
  /// 隐藏输入框
  void hideInputBox() {
    emit(state.copyWith(isInputBoxVisible: false));
  }
} 