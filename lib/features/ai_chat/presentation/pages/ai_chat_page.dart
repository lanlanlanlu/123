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

/// AI聊天页面
class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> with WidgetsBindingObserver {
  late final ChatUser _currentUser;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  String _previousText = '';

  // 输入框的全局键，用于定位输入框
  final GlobalKey _inputFieldKey = GlobalKey();

  // @按钮的全局键
  final GlobalKey _atButtonKey = GlobalKey();

  // 菜单控制器
  MentionMenuController? _menuController;

  @override
  void initState() {
    super.initState();

    // 添加观察者以监听键盘变化
    WidgetsBinding.instance.addObserver(this);

    // 创建当前用户，实际应用中应从认证服务获取用户信息
    _currentUser = ChatUser(
      id: 'user',
      firstName: '用户',
      lastName: '',
    );

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

  void _updateMentionMenuPosition() {
    // 获取输入框的位置信息
    final RenderBox? inputBox = _inputFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (inputBox == null) return;

    // 获取@按钮的位置信息
    final RenderBox? buttonBox = _atButtonKey.currentContext?.findRenderObject() as RenderBox?;

    final inputBoxPosition = inputBox.localToGlobal(Offset.zero);
    final inputBoxSize = inputBox.size;

    // 获取@按钮的位置
    Offset buttonPosition;
    if (buttonBox != null) {
      buttonPosition = buttonBox.localToGlobal(Offset.zero);
    } else {
      // 如果无法获取按钮位置，使用估计位置（输入框左侧）
      buttonPosition = Offset(
        inputBoxPosition.dx - 40, // 估计@按钮在输入框左侧40像素处
        inputBoxPosition.dy,
      );
    }

    // 计算位置：输入框的顶部
    final position = Offset(
      inputBoxPosition.dx + inputBoxSize.width / 2, // 输入框水平中心
      inputBoxPosition.dy, // 输入框顶部
    );

    // 重新显示菜单
    _showMentionMenuAt(position, buttonPosition);
  }

  void _onTextChanged() {
    final text = _textController.text;

    // 如果最后一个字符是@，显示菜单
    if (text.isNotEmpty && text.endsWith('@') && !_previousText.endsWith('@')) {
      _showMentionMenuAtCaret();
    }

    _previousText = text;
  }

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
  }

  void _showMentionMenu(BuildContext context) {
    // 通过全局键获取输入框的位置信息
    final RenderBox? inputBox = _inputFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (inputBox == null) return;

    // 获取@按钮的位置信息
    final RenderBox? buttonBox = _atButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (buttonBox == null) return;

    // 获取按钮位置
    final buttonPosition = buttonBox.localToGlobal(Offset.zero);
    // 获取输入框位置
    final inputBoxPosition = inputBox.localToGlobal(Offset.zero);
    final inputBoxSize = inputBox.size;

    // 计算位置：输入框的顶部
    final position = Offset(
      inputBoxPosition.dx + inputBoxSize.width / 2, // 输入框水平中心
      inputBoxPosition.dy, // 输入框顶部
    );

    _showMentionMenuAt(position, buttonPosition);
  }

  void _showMentionMenuAt(Offset position, Offset buttonPosition) {
    // 隐藏当前菜单（如果有）
    _hideMentionMenu();

    // 获取输入框高度
    final RenderBox? inputBox = _inputFieldKey.currentContext?.findRenderObject() as RenderBox?;
    final inputBoxHeight = inputBox?.size.height ?? 48.0;

    // 显示新菜单
    _menuController = MentionMenu.show(
      context: context,
      position: position,
      buttonPosition: buttonPosition,
      onItemSelected: _handleMentionSelected,
      onSearchSubmitted: _handleMentionSearchSubmitted,
      inputBoxHeight: inputBoxHeight,
      autofocus: false, // 禁用自动获取焦点，避免键盘问题
    );
  }

  void _showMentionMenuAtCaret() {
    // 通过全局键获取输入框的位置信息
    final RenderBox? inputBox = _inputFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (inputBox == null) return;

    // 获取@按钮的位置信息
    final RenderBox? buttonBox = _atButtonKey.currentContext?.findRenderObject() as RenderBox?;

    final inputBoxPosition = inputBox.localToGlobal(Offset.zero);
    final inputBoxSize = inputBox.size;

    // 获取@按钮的位置
    Offset buttonPosition;
    if (buttonBox != null) {
      buttonPosition = buttonBox.localToGlobal(Offset.zero);
    } else {
      // 如果无法获取按钮位置，使用估计位置（输入框左侧）
      buttonPosition = Offset(
        inputBoxPosition.dx - 40, // 估计@按钮在输入框左侧40像素处
        inputBoxPosition.dy,
      );
    }

    // 计算位置：输入框的顶部
    final position = Offset(
      inputBoxPosition.dx + inputBoxSize.width / 2, // 输入框水平中心
      inputBoxPosition.dy, // 输入框顶部
    );

    // 显示菜单
    _showMentionMenuAt(position, buttonPosition);
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
          return Column(
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
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 2,
                      offset: const Offset(0, -1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // 将标签按钮改为@按钮
                    Builder(
                      builder: (context) => IconButton(
                        key: _atButtonKey,
                        icon: const Text(
                          '@',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () => _showMentionMenu(context),
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    Expanded(
                      child: CompositedTransformTarget(
                        link: _layerLink,
                        child: TextField(
                          key: _inputFieldKey,
                          controller: _textController,
                          focusNode: _focusNode,
                          decoration: InputDecoration(
                            hintText: '输入消息...',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: _handleSendMessage,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: state.isLoading
                          ? null
                          : () => _handleSendMessage(_textController.text),
                      color: Theme.of(context).primaryColor,
                    ),
                  ],
                ),
              ),

              // 底部加载指示器
              if (state.isLoading)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: LinearProgressIndicator(),
                ),
            ],
          );
        },
      ),
    );
  }
}