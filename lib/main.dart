import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'package:record_app/app/routes/app_router.dart';
import 'package:record_app/data/database/connection/connection.dart';
import 'package:record_app/data/database/database.dart';
import 'package:record_app/data/repository/index.dart';
import 'package:record_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:record_app/features/home/presentation/bloc/home_event.dart';
import 'package:record_app/features/home/presentation/bloc/search_bloc.dart';
import 'package:record_app/features/tags/presentation/bloc/tag_list_bloc.dart';
import 'package:record_app/features/main_shell/presentation/bloc/main_shell_cubit.dart';
import 'package:record_app/data/database/connection/native.dart' show closeDatabase;
import 'package:record_app/core/utils/search_service.dart';
import 'package:record_app/core/services/sync_service.dart'; // 导入同步服务
import 'package:cloud_firestore/cloud_firestore.dart'; // 导入Firestore
import 'package:provider/provider.dart';
import 'package:record_app/features/ai_chat/presentation/providers/model_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// 导入自动生成的本地化类
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// 添加语言管理Cubit
class LocaleCubit extends Cubit<Locale?> {
  LocaleCubit([Locale? initialLocale]) : super(initialLocale);
  
  void changeLocale(Locale locale) {
    emit(locale);
  }
}

// 全局单例，避免重复创建
late final AppDatabase _database;
late final NotesRepository _notesRepository;
late final TagsRepository _tagsRepository;
late final ChatHistoryRepository _chatHistoryRepository;
late final SyncService _syncService; // 添加同步服务实例

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp( // 5. 初始化Firebase
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 获取存储的语言设置
  final prefs = await SharedPreferences.getInstance();
  final String? languageCode = prefs.getString('language_code');
  Locale? initialLocale;
  
  if (languageCode != null) {
    initialLocale = Locale(languageCode);
  }

  // 初始化数据库和仓库 (单例模式)
  await _initializeDependencies();

  // 启动后台数据库维护
  _scheduleDatabaseMaintenance();
  
  // 初始化同步服务并开始同步
  await _initializeSyncService();
  
  // 启动应用
  runApp(App(initialLocale: initialLocale));
}

/// 初始化所有依赖
Future<void> _initializeDependencies() async {
  // 1. 数据库连接
  _database = connect();
  
  // 2. 初始化仓库
  _notesRepository = NotesRepository(_database);
  _tagsRepository = TagsRepository(_database);
  _chatHistoryRepository = ChatHistoryRepository(_database);
}

/// 初始化同步服务
Future<void> _initializeSyncService() async {
  try {
    final firestore = FirebaseFirestore.instance;
    _syncService = SyncService(
      firestore: firestore,
      notesRepository: _notesRepository,
      tagsRepository: _tagsRepository,
      chatHistoryRepository: _chatHistoryRepository,
      database: _database,
    );

    // 输出同步状态诊断信息
    debugPrint('检查笔记同步状态...');
    final syncStatus = await _notesRepository.checkSyncStatusForAll();
    debugPrint('笔记同步状态统计: $syncStatus');
    
    // 仅修复有问题的笔记状态，不再盲目重置所有笔记为pending
    debugPrint('修复笔记同步状态...');
    final fixedCount = await _notesRepository.fixNoteSyncStatus();
    debugPrint('已修复 $fixedCount 个笔记的同步状态');

    // 执行同步
    debugPrint('初始化同步服务，开始同步数据...');
    await _syncService.performFullSync();
    
    // 启动周期性同步（每5分钟执行一次）
    _syncService.startPeriodicSync(interval: const Duration(minutes: 5));
    
    debugPrint('数据同步完成，已启动周期性同步');
  } catch (e) {
    debugPrint('初始化同步服务失败: $e');
  }
}

/// 在UI渲染后安排数据库维护任务
void _scheduleDatabaseMaintenance() {
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      // 确保数据库字段有合法值
      await _database.customStatement(
        'UPDATE notes SET created_at = CURRENT_TIMESTAMP WHERE created_at IS NULL'
      );
      await _database.customStatement(
        'UPDATE notes SET updated_at = CURRENT_TIMESTAMP WHERE updated_at IS NULL'
      );
      
      // 确保聊天历史相关表存在
      await _ensureChatHistoryTables();
      
      debugPrint('数据库维护完成');
    } catch (e) {
      debugPrint('运行数据库维护失败: $e');
    }
  });
}

/// 确保聊天历史表存在
Future<void> _ensureChatHistoryTables() async {
  try {
    // 尝试查询聊天历史表，如果失败表示表不存在
    await _database.customStatement('SELECT 1 FROM chat_histories LIMIT 1');
    debugPrint('聊天历史表已存在');
  } catch (e) {
    debugPrint('聊天历史表不存在，正在创建...');
    
    // 创建聊天历史表
    await _database.customStatement('''
    CREATE TABLE IF NOT EXISTS chat_histories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      last_message TEXT,
      message_count INTEGER DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      firestore_id TEXT,
      sync_status TEXT DEFAULT 'pending',
      last_synced_at DATETIME
    )
    ''');
    
    // 创建聊天消息表
    await _database.customStatement('''
    CREATE TABLE IF NOT EXISTS chat_messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      chat_history_id INTEGER NOT NULL,
      content TEXT NOT NULL,
      sender TEXT NOT NULL,
      mention_items TEXT,
      sequence_number INTEGER NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      firestore_id TEXT,
      sync_status TEXT DEFAULT 'pending',
      last_synced_at DATETIME,
      FOREIGN KEY (chat_history_id) REFERENCES chat_histories (id)
    )
    ''');
    
    debugPrint('聊天历史表创建完成');
  }
}

/// 应用根Widget
class App extends StatefulWidget {
  final Locale? initialLocale;
  
  const App({super.key, this.initialLocale});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // 注册生命周期观察者，以便在应用退出时关闭数据库
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // 取消注册生命周期观察者
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 当应用进入后台或关闭时，关闭数据库连接
    if (state == AppLifecycleState.detached) {
      _closeDatabase();
    }
  }

  void _closeDatabase() {
    try {
      // 使用connection.dart中的closeDatabase方法
      closeDatabase();
      debugPrint('Database connection closed');
    } catch (e) {
      debugPrint('Failed to close database: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        // 数据库
        RepositoryProvider<AppDatabase>(
          create: (context) => _database,
          lazy: false, // 立即创建
        ),
        // 笔记仓库
        RepositoryProvider<NotesRepository>(
          create: (context) => _notesRepository,
          lazy: false,
        ),
        // 标签仓库
        RepositoryProvider<TagsRepository>(
          create: (context) => _tagsRepository,
          lazy: false,
        ),
        // 聊天历史仓库
        RepositoryProvider<ChatHistoryRepository>(
          create: (context) => _chatHistoryRepository,
          lazy: false,
        ),
        // 为了兼容性，提供旧的Repository类
        RepositoryProvider<Repository>(
          create: (context) => Repository.fromRepositories(
            notesRepository: _notesRepository,
            tagsRepository: _tagsRepository,
          ),
          lazy: false,
        ),
        // 搜索服务
        RepositoryProvider<SearchService>(
          create: (context) => SearchService(),
          lazy: false,
        ),
        // 同步服务
        RepositoryProvider<SyncService>(
          create: (context) => _syncService,
          lazy: false,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          // 添加语言Cubit
          BlocProvider<LocaleCubit>(
            create: (context) => LocaleCubit(widget.initialLocale),
          ),
          // 首页Bloc
          BlocProvider<HomeBloc>(
            create: (context) => HomeBloc(
              notesRepository: context.read<NotesRepository>(),
            )..add(const HomeLoadNotes()),
            lazy: false, // 应用启动时就初始化
          ),
          // 标签列表Bloc
          BlocProvider<TagListBloc>(
            create: (context) => TagListBloc(
              tagsRepository: context.read<TagsRepository>(),
            )..add(const TagListLoadTags()),
            lazy: true, // 延迟初始化，仅在需要时创建
          ),
          // 主Shell Cubit
          BlocProvider<MainShellCubit>(
            create: (context) => MainShellCubit(),
          ),
          // 搜索Bloc
          BlocProvider<SearchBloc>(
            create: (context) => SearchBloc(
              searchService: context.read<SearchService>(),
            ),
            lazy: true, // 延迟初始化，仅在需要时创建
          ),
        ],
        child: const MyApp(),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 使用BlocBuilder监听语言变化
    return BlocBuilder<LocaleCubit, Locale?>(
      builder: (context, locale) {
        return MultiProvider(
          providers: [
            // 添加AI模型选择Provider
            ChangeNotifierProvider<ModelProvider>(
              create: (context) => ModelProvider(),
            ),
          ],
          child: MaterialApp.router(
            title: 'Record',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
              useMaterial3: true,
              scaffoldBackgroundColor: const Color(0xFFF7F7F7), // 添加浅灰色背景
              appBarTheme: const AppBarTheme(
                elevation: 0,
                backgroundColor: Color(0xFFF7F7F7),
                foregroundColor: Colors.black,
                titleTextStyle: TextStyle(
                  color: Colors.black,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              cardTheme: CardTheme(
                elevation: 0.5,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
            // 使用自动生成的本地化委托
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            // 使用用户选择的语言或默认语言
            locale: locale,
            routerConfig: router,
          ),
        );
      },
    );
  }
}

// 保存语言设置函数
Future<void> saveLocale(BuildContext context, Locale locale) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('language_code', locale.languageCode);
  
  // 更新语言状态
  context.read<LocaleCubit>().changeLocale(locale);
}