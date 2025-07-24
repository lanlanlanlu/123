import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart'; // 添加Provider导入
import 'package:record_app/features/calendar/presentation/pages/calendar_page.dart';
import 'package:record_app/features/home/presentation/pages/home_page.dart';
import 'package:record_app/features/ai_chat/presentation/pages/ai_chat_content.dart';
import 'package:record_app/features/ai_chat/presentation/widgets/ai_chat_app_bar.dart';
import 'package:record_app/features/main_shell/presentation/bloc/main_shell_cubit.dart';
import 'package:record_app/features/settings/presentation/pages/settings_page.dart';
import 'package:record_app/features/main_shell/presentation/widgets/bottom_nav_bar.dart';
import 'package:record_app/features/main_shell/presentation/widgets/input_sheet_overlay.dart';
import 'package:record_app/features/home/presentation/bloc/app_bar_bloc.dart';
import 'package:record_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:record_app/features/home/presentation/bloc/home_event.dart';
import 'package:record_app/features/calendar/presentation/bloc/calendar_bloc.dart';
import 'package:record_app/features/calendar/presentation/bloc/calendar_event.dart';
import 'package:record_app/features/calendar/presentation/bloc/calendar_state.dart';
import 'package:record_app/data/repository/notes_repository.dart';
import 'package:record_app/data/repository/repository.dart';
import 'package:record_app/data/repository/ai_chat_repository.dart'; // 导入AiChatRepository

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
  
  // 用于管理页面的内容
  late final List<Widget> _pageContents;
  // Bloc Providers
  late final CalendarBloc _calendarBloc;
  // 添加AI聊天仓库
  late final AiChatRepository _aiChatRepository;

  @override
  void initState() {
    super.initState();
    _draftController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 在didChangeDependencies中初始化，因为需要访问context
    _calendarBloc = CalendarBloc(
      repository: context.read<Repository>(),
    )..add(const CalendarLoadNotes());
    
    // 初始化AI聊天仓库
    _aiChatRepository = AiChatRepository();
    
    _pageContents = [
      const HomeContent(),
      const CalendarContent(),
      const AiChatContent(),
      const SettingsContent(),
    ];
  }

  @override
  void dispose() {
    _draftController.dispose();
    _overlayEntry?.remove();
    _calendarBloc.close();
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

  /// 根据当前选中的索引构建AppBar
  PreferredSizeWidget _buildAppBar(BuildContext context, int selectedIndex) {
    switch (selectedIndex) {
      case 0:
        return HomeAppBar();
      case 1:
        // 为日历AppBar提供CalendarBloc
        return PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: BlocProvider.value(
            value: _calendarBloc,
            child: CalendarAppBar(),
          ),
        );
      case 2:
        // 为AI聊天AppBar提供AiChatRepository
        return PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Provider<AiChatRepository>.value(
            value: _aiChatRepository,
            child: const AiChatAppBar(),
          ),
        );
      case 3:
        // 【核心修改】这里不再需要生成AppBar，因为SettingsPage自己管理自己的AppBar
        // 返回一个空的、零高度的AppBar即可
        return AppBar(toolbarHeight: 0, elevation: 0);
      default:
        return AppBar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MainShellCubit(),
      child: BlocBuilder<MainShellCubit, MainShellState>(
        builder: (context, state) {
          bool hasDraft = state.draftText != null && state.draftText!.isNotEmpty;
          
          return Scaffold(
            appBar: _buildAppBar(context, state.selectedIndex),
            body: IndexedStack(
              index: state.selectedIndex,
              children: [
                _pageContents[0],
                // 为日历内容提供CalendarBloc
                BlocProvider.value(
                  value: _calendarBloc,
                  child: _pageContents[1],
                ),
                // 为AI聊天内容提供AiChatRepository
                Provider<AiChatRepository>.value(
                  value: _aiChatRepository,
                  child: _pageContents[2],
                ),
                _pageContents[3],
              ],
            ),
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

/// 首页内容
class HomeContent extends StatelessWidget {
  const HomeContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final notesRepository = context.read<NotesRepository>();
        return HomeBloc(notesRepository: notesRepository)
          ..add(const HomeLoadNotes());
      },
      child: const HomeView(),
    );
  }
}

/// 首页的AppBar
class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AppBarBloc(),
      child: BlocBuilder<AppBarBloc, AppBarState>(
        builder: (context, state) {
          return AppBar(
            automaticallyImplyLeading: false, // 不显示返回按钮
            titleSpacing: 16.0,
            title: Row(
              children: [
                // 标题
                Text(
                  '笔记',
                  style: Theme.of(context).appBarTheme.titleTextStyle,
                ),
                const Spacer(),
                // 右侧图标按钮
                IconButton(
                  icon: const Icon(Icons.location_on_outlined),
                  onPressed: () => context.read<AppBarBloc>().add(AppBarLocationPressed(context)),
                ),
                IconButton(
                  icon: const Icon(Icons.tag),
                  onPressed: () => context.read<AppBarBloc>().add(AppBarTagPressed(context)),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => context.read<AppBarBloc>().add(AppBarSearchPressed()),
                ),
                IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => context.read<AppBarBloc>().add(AppBarMenuPressed()),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 日历页面内容
class CalendarContent extends StatelessWidget {
  const CalendarContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 直接使用已存在的CalendarBloc，不再创建新的实例
    return const CalendarView();
  }
}

/// 日历页面的AppBar
class CalendarAppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CalendarBloc, CalendarState>(
      builder: (context, state) {
        final selectedDate = state.selectedDate;
        final now = DateTime.now();
        final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
        final weekdayText = weekdays[selectedDate.weekday - 1];

        return AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.grey[50],
          elevation: 0,
          titleSpacing: 16.0,
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 左边：几月几号
              Text(
                '${selectedDate.month}月${selectedDate.day}日',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 4),
              // 右边：上半部分年份，下半部分周几
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 上半部分：年份
                  Text(
                    '${selectedDate.year}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                      color: Colors.black87,
                    ),
                  ),
                  // 下半部分：周几
                  Text(
                    weekdayText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // 右侧"今天"按钮
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      context.read<CalendarBloc>().add(const CalendarGoToToday());
                    },
                    child: Center(
                      child: Text(
                        '${now.day}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 即将推出功能页面内容
class ComingSoonContent extends StatelessWidget {
  const ComingSoonContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
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
    );
  }
}

/// 设置页面内容
class SettingsContent extends StatelessWidget {
  const SettingsContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 使用SettingsPage替代之前的文本显示
    return const SettingsPage();
  }
}