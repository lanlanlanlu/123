import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:record/features/calendar/presentation/pages/calendar_page.dart';
import 'package:record/features/home/presentation/pages/home_page.dart';
import 'package:record/features/main_shell/presentation/bloc/main_shell_cubit.dart';
import 'package:record/features/settings/presentation/pages/settings_page.dart';
import 'package:record/features/main_shell/presentation/widgets/bottom_nav_bar.dart';
import 'package:record/features/main_shell/presentation/widgets/input_sheet_overlay.dart';

/// 草稿键值常量
const String DRAFT_KEY = 'note_draft';

class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  OverlayEntry? _overlayEntry;
  late final TextEditingController _draftController;

  // 使用懒加载模式创建页面
  late final List<Widget> _pages = [
    const HomePage(),
    // 其他页面使用懒加载方式初始化
    const Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(56),
        child: SizedBox(),
      ),
      body: Center(child: CircularProgressIndicator())
    ),
    const Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(56),
        child: SizedBox(),
      ),
      body: Center(child: CircularProgressIndicator())
    ),
    const Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(56),
        child: SizedBox(),
      ),
      body: Center(child: CircularProgressIndicator())
    ),
  ];
  
  // 跟踪页面是否已加载
  final List<bool> _pagesLoaded = [true, false, false, false];

  @override
  void initState() {
    super.initState();
    _draftController = TextEditingController();
    
    // 延迟加载其他页面
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _pages[1] = const Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(56),
              child: SizedBox(),
            ),
            body: CalendarPage()
          );
          _pagesLoaded[1] = true;
        });
      }
    });
    
    // 进一步延迟加载剩余页面
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          // 将标签页改为空白页，为将来的功能留出空间
          _pages[2] = Scaffold(
            appBar: AppBar(
              title: const Text('即将推出'),
              centerTitle: true,
            ),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.construction,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '功能开发中...',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
            ),
                ],
              ),
            ),
          );
          _pagesLoaded[2] = true;
          
          _pages[3] = const Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(56),
              child: SizedBox(),
            ),
            body: SettingsPage()
          );
          _pagesLoaded[3] = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _draftController.dispose();
    _overlayEntry?.remove();
    super.dispose();
  }

  /// 显示笔记输入表单
  void _showNoteInputSheet(BuildContext context, String? draftText) {
    // 更新Cubit状态
    context.read<MainShellCubit>().showInputBox();
    
    _draftController.text = draftText ?? '';
    _overlayEntry?.remove();
    
    // 使用InputSheetOverlay创建覆盖层
    _overlayEntry = InputSheetOverlay.create(
      context: context,
      controller: _draftController,
      onDismiss: (text) => _hideNoteInputSheet(context, text),
    );
    
    Overlay.of(context).insert(_overlayEntry!);
  }

  /// 隐藏笔记输入表单
  Future<void> _hideNoteInputSheet(BuildContext context, String currentText) async {
    // 保存草稿并更新Cubit状态
    await context.read<MainShellCubit>().saveDraft(currentText);
    context.read<MainShellCubit>().hideInputBox();
    
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MainShellCubit(),
      child: BlocBuilder<MainShellCubit, MainShellState>(
        builder: (context, state) {
          bool hasDraft = state.draftText != null && state.draftText!.isNotEmpty;
          
          return Scaffold(
            body: IndexedStack(index: state.selectedIndex, children: _pages),
            // 浮动操作按钮 - 仅在首页且输入框未显示时显示
            floatingActionButton: state.selectedIndex == 0 && !state.isInputBoxVisible
                ? FloatingActionButton(
                    onPressed: () => _showNoteInputSheet(context, state.draftText),
                    tooltip: hasDraft ? '继续笔记' : '新建笔记',
                    shape: const CircleBorder(),
                    child: Icon(hasDraft ? Icons.draw_outlined : Icons.add),
                  )
                : null,
            floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
            // 使用重构后的底部导航栏组件
            bottomNavigationBar: BottomNavBar(
              selectedIndex: state.selectedIndex,
              onItemTapped: (index) => context.read<MainShellCubit>().changeIndex(index),
            ),
          );
        },
      ),
    );
  }
}