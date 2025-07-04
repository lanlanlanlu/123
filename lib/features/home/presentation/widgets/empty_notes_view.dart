import 'package:flutter/material.dart';

/// 空笔记视图组件，当没有笔记时显示的提示信息
class EmptyNotesView extends StatelessWidget {
  const EmptyNotesView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '还没有笔记，\n点击右下角的 "+" 添加第一条吧！',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, color: Colors.grey),
      ),
    );
  }
} 