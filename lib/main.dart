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
import 'package:record_app/core/services/auth_service.dart'; // 导入生物认证服务
import 'package:cloud_firestore/cloud_firestore.dart'; // 导入Firestore
import 'package:provider/provider.dart';
import 'package:record_app/features/ai_chat/presentation/providers/model_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// 导入自动生成的本地化类
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
// 导入主题相关类
import 'package:record_app/app/theme/app_theme.dart';
import 'package:record_app/app/theme/theme_cubit.dart';
import 'dart:io' show Platform; // 导入Platform

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
  // 添加认证状态
  bool _isAuthenticated = false;
  final BiometricAuthService _authService = BiometricAuthService();
  // 添加防止重复认证的标志
  bool _isAuthenticating = false;
  // 添加静态变量记录上次认证时间
  static DateTime? _lastAuthTime;
  
  // 安全获取本地化字符串
  String _getLocalizedString(BuildContext context, String key, String defaultValue) {
    try {
      final s = AppLocalizations.of(context);
      if (s == null) return defaultValue;
      
      switch (key) {
        case 'authBiometricRequired':
          return s.authBiometricRequired;
        case 'authBiometricReason':
          return s.authBiometricReason;
        case 'ok':
          return s.ok;
        default:
          return defaultValue;
      }
    } catch (e) {
      debugPrint('获取本地化字符串失败: $e');
      return defaultValue;
    }
  }
  
  @override
  void initState() {
    super.initState();
    // 注册生命周期观察者，以便在应用退出时关闭数据库
    WidgetsBinding.instance.addObserver(this);
    
    // 检查是否需要生物认证
    _checkBiometricAuth();
  }

  // 检查生物认证
  Future<void> _checkBiometricAuth() async {
    final isBiometricEnabled = await _authService.isBiometricEnabled();
    
    // 如果未启用生物认证，则直接通过认证
    if (!isBiometricEnabled) {
      setState(() {
        _isAuthenticated = true;
      });
      return;
    }
    
    // 延迟一点时间确保应用UI已加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 只在应用首次启动时进行认证，避免重复认证
      if (!_isAuthenticated && !_isAuthenticating) {
        _authenticate();
      }
    });
  }
  
  // 执行认证
  Future<void> _authenticate() async {
    // 防止重复认证
    if (_isAuthenticated || _isAuthenticating) return;
    
    // 设置认证中标志
    _isAuthenticating = true;
    
    try {
      // 检查设备是否支持生物认证
      final isAvailable = await _authService.isBiometricAvailable();
      if (!isAvailable) {
        // 如果设备不支持，显示提示并禁用该功能
        await _authService.setBiometricEnabled(false);
        setState(() {
          _isAuthenticated = true;
        });
        // 更新认证时间
        _lastAuthTime = DateTime.now();
        return;
      }
      
      // 执行认证
      final isAuthenticated = await _authService.authenticate(context);
      
      if (mounted) {
        setState(() {
          _isAuthenticated = isAuthenticated;
        });
      }
      
      // 如果认证成功，更新上次认证时间
      if (isAuthenticated) {
        _lastAuthTime = DateTime.now();
        debugPrint('认证成功，更新认证时间: $_lastAuthTime');
      }
      
      // 如果认证失败，尝试再次认证
      if (!isAuthenticated && mounted) {
        Future.delayed(const Duration(seconds: 1), () {
          _isAuthenticating = false; // 重置认证中标志
          _authenticate();
        });
      }
    } finally {
      // 确保认证过程结束后重置标志
      _isAuthenticating = false;
    }
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
    
    // 当应用从后台恢复时，重新检查认证状态
    if (state == AppLifecycleState.resumed) {
      _checkBiometricAuthOnResume();
    }
  }
  
  // 应用从后台恢复时检查认证
  Future<void> _checkBiometricAuthOnResume() async {
    // 如果正在认证中，不要重复触发
    if (_isAuthenticating) return;
    
    final isBiometricEnabled = await _authService.isBiometricEnabled();
    
    // 如果启用了生物认证，且之前已经通过验证，则需要重新验证
    // 但在Windows平台上，避免重复验证
    bool isWindows = false;
    try {
      isWindows = Platform.isWindows;
    } catch (e) {
      debugPrint('平台检测失败: $e');
    }
    
    // 添加一个时间检查，避免短时间内重复触发认证
    // 使用静态变量存储上次认证时间
    final now = DateTime.now();
    final lastAuthTime = _AppState._lastAuthTime;
    final timeSinceLastAuth = lastAuthTime != null ? now.difference(lastAuthTime) : null;
    
    // 如果上次认证在30秒内，则不重新验证
    if (timeSinceLastAuth != null && timeSinceLastAuth.inSeconds < 30) {
      debugPrint('上次认证在30秒内，跳过重新认证');
      return;
    }
    
    if (isBiometricEnabled && _isAuthenticated && !isWindows && !_isAuthenticating) {
      setState(() {
        _isAuthenticated = false;
      });
      
      // 延迟一点时间再显示认证界面
      Future.delayed(const Duration(milliseconds: 500), () {
        _authenticate();
      });
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
    // 如果未认证，显示一个锁屏界面
    if (!_isAuthenticated) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fingerprint, size: 64, color: Colors.deepPurple),
                    const SizedBox(height: 16),
                    Text(
                      _getLocalizedString(context, 'authBiometricRequired', 'Authentication required'),
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isAuthenticating ? null : () {
                        _authenticate();
                      },
                      child: Text(_getLocalizedString(context, 'authBiometricReason', 'Authenticate')),
                    ),
                  ],
                ),
              ),
            );
          }
        ),
      );
    }
    
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
          // 添加主题Cubit
          BlocProvider<ThemeCubit>(
            create: (context) => ThemeCubit()..initTheme(),
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
    // 使用BlocBuilder监听语言和主题变化
    return BlocBuilder<LocaleCubit, Locale?>(
      builder: (context, locale) {
        return BlocBuilder<ThemeCubit, ThemeState>(
          builder: (context, themeState) {
            // 根据主题模式获取相应的主题
            final ThemeData lightTheme = AppTheme.getLightTheme();
            final ThemeData darkTheme = AppTheme.getDarkTheme();
            
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
                theme: lightTheme,
                darkTheme: darkTheme,
                themeMode: themeState.themeMode,
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