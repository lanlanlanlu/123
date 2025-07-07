import 'package:go_router/go_router.dart';
import 'package:record_app/features/main_shell/presentation/widgets/main_shell_page.dart';
import 'package:record_app/features/note_detail/presentation/pages/note_detail_page.dart';
import 'package:record_app/data/database/database.dart'; // 导入 Note 类

// 1. 创建 GoRouter 配置
final GoRouter router = GoRouter(
  // 初始路由路径
  initialLocation: '/',
  // 定义所有路由规则
  routes: [
    // 主页路由
    GoRoute(
      path: '/',
      builder: (context, state) => const MainShellPage(),
      // 定义一个子路由，用于笔记详情页
      routes: [
        GoRoute(
          name: 'noteDetail', // 给路由起个名字，方便调用
          path: 'note/:id',   // 路径中包含一个动态参数 "id"
          builder: (context, state) {
            // 从路径中获取笔记对象
            final note = state.extra as Note;
            return NoteDetailPage(note: note);
          },
        ),
      ],
    ),
  ],
);