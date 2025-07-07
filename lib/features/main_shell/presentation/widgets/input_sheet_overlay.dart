import 'package:flutter/material.dart';
import 'package:record_app/features/main_shell/presentation/widgets/note_input_sheet.dart';

/// 笔记输入覆盖层组件
class InputSheetOverlay extends StatelessWidget {
  /// 文本控制器
  final TextEditingController controller;
  
  /// 关闭覆盖层回调
  final ValueChanged<String> onDismiss;

  const InputSheetOverlay({
    super.key,
    required this.controller,
    required this.onDismiss,
  });

  /// 创建覆盖层条目
  static OverlayEntry create({
    required BuildContext context,
    required TextEditingController controller,
    required ValueChanged<String> onDismiss,
  }) {
    return OverlayEntry(
      builder: (overlayContext) => InputSheetOverlay(
        controller: controller,
        onDismiss: onDismiss,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 半透明背景，点击时关闭表单
        Positioned.fill(
          child: GestureDetector(
            onTap: () => onDismiss(controller.text),
            child: Container(
              color: Colors.black.withOpacity(0.3),
            ),
          ),
        ),
        // 输入表单，位于底部，随键盘高度调整
        Positioned(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 0,
          right: 0,
          child: NoteInputSheet(
            controller: controller,
            onDismiss: onDismiss,
          ),
        ),
      ],
    );
  }
} 