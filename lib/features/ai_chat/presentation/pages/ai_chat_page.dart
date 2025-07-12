import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import '../bloc/ai_chat_bloc.dart';
import '../widgets/chat_error_display.dart';
import 'package:intl/intl.dart';

/// AI聊天页面
class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  late final AiChatBloc _aiChatBloc;
  late final ChatUser _currentUser;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _aiChatBloc = AiChatBloc();
    _aiChatBloc.add(const AiChatInitialized());
    
    // 创建当前用户，实际应用中应从认证服务获取用户信息
    _currentUser = ChatUser(
      id: 'user',
      firstName: '用户',
      lastName: '',
    );
  }

  @override
  void dispose() {
    _aiChatBloc.close();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _handleSendMessage(String message) {
    if (message.trim().isEmpty) return;
    
    final chatMessage = ChatMessage(
      user: _currentUser,
      text: message,
      createdAt: DateTime.now(),
    );
    
    _aiChatBloc.add(AiChatMessageSent(chatMessage));
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _aiChatBloc,
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
                    final reversedIndex = state.messages.length - 1 - index;
                    final message = state.messages[reversedIndex];
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
                    IconButton(
                      icon: const Icon(Icons.tag),
                      onPressed: () {
                        // TODO: 显示标签选择器
                      },
                      color: Theme.of(context).primaryColor,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _textController,
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