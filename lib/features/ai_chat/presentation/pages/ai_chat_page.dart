import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import '../bloc/ai_chat_bloc.dart';
import '../bloc/ai_chat_event.dart';
import '../bloc/ai_chat_state.dart';
import '../widgets/chat_error_display.dart';
import '../widgets/mention_menu.dart';
import 'package:intl/intl.dart';
import 'package:record_app/data/repository/ai_chat_repository.dart';
import 'package:flutter/rendering.dart';
import 'package:record_app/data/repository/recent_mentions_repository.dart';

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
  final ChatUser _currentUser = ChatUser(
    id: 'user_1', 
    firstName: '我'
  );
  
  // 最近提及仓库
  final RecentMentionsRepository _recentMentionsRepository = RecentMentionsRepository();

  @override
  void initState() {
    super.initState();
    
    // 添加观察者以监听键盘变化
    WidgetsBinding.instance.addObserver(this);
    
    // 添加文本监听器
    _textController.addListener(_onTextChanged);
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
    super.dispose();
  }
  
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    
    // 当键盘状态变化时，如果菜单正在显示，先隐藏菜单
    // 避免菜单跟随输入框重新定位，这会导致键盘自动弹出
    if (_menuController?.isShowing == true) {
      _hideMentionMenu();
    }
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
    } else if (_lastAtPosition != -1 && 
              (text.isEmpty || 
               _lastAtPosition >= text.length || 
               text[_lastAtPosition] != '@')) {
      // 如果之前有@但现在被删除了，重置位置
      _lastAtPosition = -1;
    }
  }
  
  // 记录上次触发@菜单的位置，避免重复触发
  int _lastAtPosition = -1;
  
  void _hideMentionMenu() {
    _menuController?.hide();
    _menuController = null;
  }
  
  void _handleSendMessage(String message) {
    if (message.trim().isEmpty) return;
    
    final chatMessage = ChatMessage(
      user: _currentUser,
      text: message,
      createdAt: DateTime.now(),
    );
    
    // 从 context 中读取由 BlocProvider 提供的 BLoC 实例
    context.read<AiChatBloc>().add(AiChatMessageSent(chatMessage));
    _textController.clear();
  }

  void _handleMentionSelected(MentionItem item) {
    // 根据选择的提及项添加到输入框中
    final currentText = _textController.text;
    final mentionText = '@${item.title} ';
    
    // 插入@提及
    if (currentText.endsWith('@')) {
      _textController.text = currentText.substring(0, currentText.length - 1) + mentionText;
    } else {
      _textController.text = currentText + mentionText;
    }
    
    // 将光标移至末尾
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: _textController.text.length),
    );
    
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
    // 处理搜索提交
    final mentionText = '@$text ';
    
    // 插入@提及
    final currentText = _textController.text;
    if (currentText.endsWith('@')) {
      _textController.text = currentText.substring(0, currentText.length - 1) + mentionText;
    } else {
      _textController.text = currentText + mentionText;
    }
    
    // 将光标移至末尾
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: _textController.text.length),
    );
    
    // 异步记录最近使用的搜索提及，避免阻塞UI
    Future.microtask(() {
      _recentMentionsRepository.addRecentMention(
        type: 'search',
        itemId: text,
        title: text,
      );
    });
  }

  void _showMentionMenu() {
    // 隐藏当前菜单（如果有）
    _hideMentionMenu();
    
    // 显示新菜单，使用LayerLink进行精确定位
    _menuController = MentionMenu.show(
      context: context, 
      layerLink: _inputFieldLayerLink,
      onItemSelected: _handleMentionSelected,
      onSearchSubmitted: _handleMentionSearchSubmitted,
      verticalOffset: -5, // 向上偏移，显示在输入框上方
      horizontalOffset: 10, // 水平偏移，使菜单与输入框有一定距离
      menuWidth: 220.0,
      autofocus: false, // 禁用自动获取焦点，避免键盘问题
    );
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
        },
        builder: (context, state) {
          return Container(
            color: Colors.grey[50], // 浅灰色背景，类似图片中的背景色
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
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  message.text,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0, left: 4.0),
                                child: Text(
                                  DateFormat('HH:mm').format(message.createdAt),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                                  ),
                                  padding: const EdgeInsets.all(12.0),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    message.text,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                CircleAvatar(
                                  radius: 15,
                                  backgroundColor: Theme.of(context).primaryColor,
                                  child: const Icon(
                                    Icons.person,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0, right: 4.0),
                              child: Text(
                                DateFormat('HH:mm').format(message.createdAt),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        )
                      ],
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.15),
                        width: 0.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 文本输入框
                        CompositedTransformTarget(
                          link: _inputFieldLayerLink,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 4.0),
                            child: TextField(
                              controller: _textController,
                              focusNode: _focusNode,
                              minLines: 1,
                              maxLines: 5, // 允许自动扩展到最多5行
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.3,
                              ),
                              decoration: const InputDecoration(
                                hintText: '发个v个哥哥哥吧好吧哈哈哈哈哈哈哈发个',
                                hintStyle: TextStyle(
                                  color: Colors.black45,
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
                        
                        // 底部按钮栏
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          child: Row(
                            children: [
                              // @按钮
                              IconButton(
                                icon: const Icon(
                                  Icons.add,
                                  color: Colors.black54,
                                  size: 26,
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
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.arrow_forward,
                                    color: state.isLoading ? Colors.grey : Colors.black,
                                    size: 22,
                                  ),
                                  onPressed: state.isLoading
                                      ? null
                                      : () => _handleSendMessage(_textController.text),
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
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}