import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:dash_chat_2/dash_chat_2.dart' as dash;
import '../bloc/ai_chat_bloc.dart';
import '../bloc/ai_chat_event.dart';
import '../bloc/ai_chat_state.dart';
import '../widgets/chat_error_display.dart';
import '../widgets/mention_menu.dart';
import 'package:intl/intl.dart';
import 'package:record_app/data/repository/ai_chat_repository.dart';
import 'package:flutter/rendering.dart';
import 'package:record_app/data/repository/recent_mentions_repository.dart';
import 'package:record_app/data/models/chat_reference.dart';

/// AI聊天页面
class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  
  // 用于菜单定位的链接
  final LayerLink _inputFieldLayerLink = LayerLink();
  
  // 菜单控制器
  MentionMenuController? _menuController;
  
  // 当前用户（使用dash_chat_2中的ChatUser）
  final dash.ChatUser _currentUser = dash.ChatUser(
    id: 'user_1', 
    firstName: '我'
  );
  
  // 最近提及仓库
  final RecentMentionsRepository _recentMentionsRepository = RecentMentionsRepository();
  
  // AiChatBloc引用，避免在dispose时通过context访问
  AiChatBloc? _aiChatBloc;

  // 存储@提及项目的列表
  final List<MentionItem> _mentionItems = [];
  
  // 输入框中的文本，用于管理带@提及的内容
  String _plainText = '';
  
  // 记录上一次状态中的消息数量，用于检测新消息
  int _lastMessageCount = 0;
  
  // 将MentionType转换为ReferenceType
  ReferenceType _convertMentionTypeToReferenceType(MentionType type) {
    switch (type) {
      case MentionType.note:
        return ReferenceType.note;
      case MentionType.tag:
        return ReferenceType.tag;
      case MentionType.location:
        return ReferenceType.location;
    }
  }

  @override
  void initState() {
    super.initState();
    
    // 添加观察者以监听键盘变化
    WidgetsBinding.instance.addObserver(this);
    
    // 添加文本监听器
    _textController.addListener(_onTextChanged);
    
    debugPrint('AiChatPage: initState() 被调用');
  }
  
  @override
  void dispose() {
    // 移除观察者
    WidgetsBinding.instance.removeObserver(this);
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _hideMentionMenu();
    
    debugPrint('AiChatPage: dispose() 被调用');
    super.dispose();
  }
  
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
  }
  
  void _onTextChanged() {
    final text = _textController.text;
    final selection = _textController.selection;
    
    // 检查当前光标位置前的字符是否为@
    if (text.isNotEmpty && 
        selection.baseOffset > 0 && 
        selection.baseOffset <= text.length && 
        text[selection.baseOffset - 1] == '@' &&
        (_lastAtPosition == -1 || _lastAtPosition != selection.baseOffset - 1)) {
      
      // 记录当前@的位置，避免重复触发
      _lastAtPosition = selection.baseOffset - 1;
      _showMentionMenu();
    } else if (_lastAtPosition != -1) {
      // 如果之前有@，检查是否需要关闭菜单
      if (text.isEmpty || 
          _lastAtPosition >= text.length || 
          text[_lastAtPosition] != '@') {
        // 如果@被删除，重置位置
        _lastAtPosition = -1;
        _hideMentionMenu();
      } else if (selection.baseOffset > _lastAtPosition + 1) {
        // 如果用户在@之后继续输入了其他字符，关闭菜单
        // 但保留_lastAtPosition的值，避免重新触发菜单
        _hideMentionMenu();
      }
    }
    
    // 更新纯文本内容
    _plainText = text;
  }
  
  // 记录上次触发@菜单的位置，避免重复触发
  int _lastAtPosition = -1;
  
  void _hideMentionMenu() {
    _menuController?.hide();
    _menuController = null;
  }
  
  void _handleSendMessage(String message) {
    if (message.trim().isEmpty) return;
    
    // 清除@提及项列表和输入框
    _textController.clear();
    setState(() {
      _mentionItems.clear();
      _plainText = '';
    });
  }

  void _handleMentionSelected(MentionItem item) {
    // 添加到@提及项列表
    setState(() {
      _mentionItems.add(item);
    });
    
    // 安全处理光标位置
    String currentText = _textController.text;
    
    // 删除刚才输入的@
    if (currentText.endsWith('@')) {
      final newText = currentText.substring(0, currentText.length - 1);
      // 直接使用值更新文本，不触发光标位置变化
      _textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
    
    // 更新纯文本内容
    _plainText = _textController.text;
    
    // 异步记录最近使用的提及，避免阻塞UI
    Future.microtask(() {
      switch (item.type) {
        case MentionType.note:
          _recentMentionsRepository.addRecentMention(
            type: 'note',
            itemId: item.id,
            title: item.title,
          );
          break;
        case MentionType.tag:
          _recentMentionsRepository.addTagMention(item.title);
          break;
        case MentionType.location:
          _recentMentionsRepository.addLocationMention(item.title);
          break;
      }
    });
  }

  void _handleMentionSearchSubmitted(String text) {
    if (text.isEmpty) return;
    
    // 添加到@提及项列表，作为自定义项
    setState(() {
      _mentionItems.add(MentionItem(
        id: text,
        title: text,
        type: MentionType.tag,
      ));
    });
    
    // 安全处理光标位置
    String currentText = _textController.text;
    
    // 删除刚才输入的@
    if (currentText.endsWith('@')) {
      final newText = currentText.substring(0, currentText.length - 1);
      // 直接使用值更新文本，不触发光标位置变化
      _textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
    
    // 更新纯文本内容
    _plainText = _textController.text;
    
    // 不再将搜索提交的内容添加到最近提及数据库
    // 只有通过菜单选择的项目才会被记录
  }

  void _showMentionMenu() {
    // 隐藏当前菜单（如果有）
    if (_menuController != null) {
      _menuController?.dispose();
      _menuController = null;
    }
    
    // 显示新菜单，使用LayerLink进行精确定位
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 计算菜单应该显示的垂直偏移量
      // 如果有提及项，上移菜单到更高的位置
      final double verticalOffset = _mentionItems.isNotEmpty ? -50.0 : -5.0;
      
      // 获取水平距离，用于设置等于的垂直间距
      final horizontalPadding = 10.0;
      
      _menuController = MentionMenu.show(
        context: context, 
        layerLink: _inputFieldLayerLink,
        onItemSelected: _handleMentionSelected,
        onSearchSubmitted: _handleMentionSearchSubmitted,
        verticalOffset: verticalOffset, // 根据是否有提及项动态调整垂直偏移
        horizontalOffset: horizontalPadding, // 水平偏移，使菜单与输入框有一定距离
        menuWidth: 220.0,
        autofocus: false, // 禁用自动获取焦点，避免键盘问题
      );
    });
  }
  
  // 移除某个@提及项
  void _removeMentionItem(MentionItem item) {
    setState(() {
      _mentionItems.remove(item);
    });
  }
  
  // 根据提及类型获取对应图标
  IconData _getIconForMentionType(MentionType type) {
    switch (type) {
      case MentionType.note:
        return Icons.description;
      case MentionType.tag:
        return Icons.label;
      case MentionType.location:
        return Icons.location_on;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _aiChatBloc = context.read<AiChatBloc>();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: context.read<AiChatBloc>(),
      child: BlocConsumer<AiChatBloc, AiChatState>(
        listener: (context, state) {
          // 当有新消息时，滚动到底部
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients && state.messages.isNotEmpty) {
              _scrollController.animateTo(
                0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
          
          // 不在这里实时保存消息，依靠AiChatContent中的保存逻辑
          _lastMessageCount = state.messages.length;
        },
        builder: (context, state) {
          final theme = Theme.of(context);
          final isDarkMode = theme.brightness == Brightness.dark;
          
          return Material(
            color: theme.scaffoldBackgroundColor,
            child: Column(
              children: [
                // 错误提示（如果有）
                if (state.error != null)
                  ChatErrorDisplay(error: state.error!),
                
                // 聊天消息列表
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8.0),
                    reverse: true,
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final message = state.messages.reversed.toList()[index];
                      final isAi = message.user.id == 'ai_assistant';
                      
                      // AI消息
                      if (isAi) {
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                                ),
                                padding: const EdgeInsets.all(12.0),
                                decoration: BoxDecoration(
                                  color: isDarkMode 
                                      ? theme.colorScheme.surfaceVariant.withOpacity(0.7)
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  message.text,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: theme.textTheme.bodyMedium?.color,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0, left: 4.0),
                                child: Text(
                                  DateFormat('HH:mm').format(message.createdAt),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      // 用户消息
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.8,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                              decoration: BoxDecoration(
                                color: isDarkMode 
                                    ? theme.colorScheme.primary.withOpacity(0.2)
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // 如果有提及项，显示提及项
                                  if (message.customProperties != null && 
                                      message.customProperties!.containsKey('mentionItems') &&
                                      (message.customProperties!['mentionItems'] as List).isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: Wrap(
                                        spacing: 4.0,
                                        runSpacing: 4.0,
                                        children: [
                                          ...(message.customProperties!['mentionItems'] as List).map((item) {
                                            final MentionType mentionType = MentionType.values[item['type'] as int];
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                              decoration: BoxDecoration(
                                                color: isDarkMode
                                                    ? theme.colorScheme.surface
                                                    : Colors.grey[100],
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: isDarkMode
                                                      ? Colors.grey.withOpacity(0.5)
                                                      : Colors.grey.withOpacity(0.3),
                                                  width: 0.5
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    _getIconForMentionType(mentionType),
                                                    size: 14,
                                                    color: theme.colorScheme.primary,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    item['title'] as String,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      height: 1.0,
                                                      color: theme.textTheme.bodyMedium?.color,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ],
                                      ),
                                    ),
                                  
                                  // 消息文本
                                  Text(
                                    message.text,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: theme.textTheme.bodyMedium?.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0, right: 4.0),
                              child: Text(
                                DateFormat('HH:mm').format(message.createdAt),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                
                // 底部输入框
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDarkMode ? theme.colorScheme.surface : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: isDarkMode
                              ? Colors.black.withOpacity(0.2)
                              : Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        )
                      ],
                      border: Border.all(
                        color: isDarkMode
                            ? Colors.grey.withOpacity(0.3)
                            : Colors.grey.withOpacity(0.15),
                        width: 0.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // @提及项的显示区域
                        if (_mentionItems.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 10.0, left: 16.0, right: 16.0),
                            child: SizedBox(
                              height: 30,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                itemCount: _mentionItems.length,
                                separatorBuilder: (context, index) => const SizedBox(width: 6),
                                itemBuilder: (context, index) {
                                  final item = _mentionItems[index];
                                  return InputChip(
                                    avatar: Icon(
                                      _getIconForMentionType(item.type),
                                      size: 14,
                                      color: theme.colorScheme.primary,
                                    ),
                                    label: Text(
                                      item.title,
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.0,
                                        color: theme.textTheme.bodyMedium?.color,
                                      ),
                                    ),
                                    labelPadding: EdgeInsets.zero,
                                    backgroundColor: isDarkMode
                                        ? theme.colorScheme.surfaceVariant
                                        : Colors.grey[100],
                                    deleteIcon: Icon(
                                      Icons.close, 
                                      size: 12,
                                      color: isDarkMode
                                          ? Colors.grey[300]
                                          : Colors.grey[700],
                                    ),
                                    onDeleted: () => _removeMentionItem(item),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                    padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 0),
                                  );
                                },
                              ),
                            ),
                          ),
                          
                        // 文本输入框
                        CompositedTransformTarget(
                          link: _inputFieldLayerLink,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 4.0),
                            child: Material(
                              color: Colors.transparent,
                              child: TextField(
                                controller: _textController,
                                focusNode: _focusNode,
                                minLines: 1,
                                maxLines: 5, // 允许自动扩展到最多5行
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.3,
                                  color: theme.textTheme.bodyMedium?.color,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Ask me notes or anything',
                                  hintStyle: TextStyle(
                                    color: isDarkMode ? Colors.grey[400] : Colors.black45,
                                    fontSize: 16,
                                    height: 1.3,
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  fillColor: Colors.transparent,
                                  filled: true,
                                  isDense: true,
                                ),
                                textInputAction: TextInputAction.newline,
                              ),
                            ),
                          ),
                        ),
                        
                        // 底部按钮栏
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          child: Row(
                            children: [
                              // @按钮
                              IconButton(
                                icon: Text(
                                  '@',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode ? Colors.grey[300] : Colors.black54,
                                  ),
                                ),
                                onPressed: _showMentionMenu,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                              ),
                              
                              const Spacer(),
                              
                              // 发送按钮
                              Container(
                                height: 40,
                                width: 40,
                                decoration: BoxDecoration(
                                  color: isDarkMode 
                                      ? theme.colorScheme.surfaceVariant
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.arrow_forward,
                                    color: state.isLoading 
                                        ? (isDarkMode ? Colors.grey[600] : Colors.grey)
                                        : (isDarkMode ? theme.colorScheme.onSurface : Colors.black),
                                    size: 22,
                                  ),
                                  onPressed: state.isLoading
                                      ? null
                                      : () {
                                          // 构建发送文本：结合纯文本和@提及项
                                          String messageText = _plainText;
                                          
                                          // 创建引用对象列表
                                          final references = _mentionItems.map((item) => 
                                            ChatReference(
                                              id: item.id,
                                              title: item.title,
                                              type: _convertMentionTypeToReferenceType(item.type),
                                            )
                                          ).toList();
                                          
                                          // 不再在消息文本中添加提及标记
                                          // 使用原始纯文本作为消息文本
                                          final formattedMessage = messageText.trim();
                                          if (formattedMessage.isEmpty) return;
                                          
                                          // 创建聊天消息，将提及项存储在customProperties中
                                          final chatMessage = dash.ChatMessage(
                                            user: _currentUser,
                                            text: formattedMessage,
                                            createdAt: DateTime.now(),
                                            customProperties: {
                                              'mentionItems': _mentionItems.map((item) => {
                                                'id': item.id,
                                                'title': item.title,
                                                'type': item.type.index,
                                              }).toList(),
                                            },
                                          );
                                          
                                          // 发送消息和引用对象
                                          _aiChatBloc?.add(
                                            AiChatMessageSent(chatMessage, references: references)
                                          );
                                          
                                          // 清理UI状态
                                          _textController.clear();
                                          setState(() {
                                            _mentionItems.clear();
                                            _plainText = '';
                                          });
                                          
                                          // 调试: 打印当前使用的聊天ID
                                          final bloc = context.read<AiChatBloc>();
                                          debugPrint('AiChatPage: 发送消息，使用聊天ID：${bloc.chatHistoryId}');
                                        },
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // 底部加载指示器
                if (state.isLoading)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: LinearProgressIndicator(
                      backgroundColor: isDarkMode 
                          ? Colors.grey[800] 
                          : Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}