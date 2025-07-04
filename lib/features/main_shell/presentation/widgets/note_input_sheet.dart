import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:record/data/repository/index.dart';
import 'package:record/features/main_shell/presentation/bloc/note_input_cubit.dart';
import 'package:record/features/main_shell/presentation/widgets/note_input_toolbar.dart';

/// 笔记输入表单组件
class NoteInputSheet extends StatefulWidget {
  /// 文本控制器
  final TextEditingController controller;
  
  /// 关闭表单回调
  final ValueChanged<String> onDismiss;

  const NoteInputSheet({
    super.key, 
    required this.onDismiss, 
    required this.controller
  });

  @override
  State<NoteInputSheet> createState() => _NoteInputSheetState();
}

class _NoteInputSheetState extends State<NoteInputSheet> {
  final FocusNode _focusNode = FocusNode();
  final GlobalKey _tagButtonKey = GlobalKey();
  late NoteInputCubit _noteInputCubit;

  @override
  void initState() {
    super.initState();
    _noteInputCubit = NoteInputCubit(
      notesRepository: Provider.of<NotesRepository>(context, listen: false),
    );
    // 设置初始文本
    _noteInputCubit.updateText(widget.controller.text);
    // 监听文本变化
    widget.controller.addListener(_onTextChanged);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    _noteInputCubit.close();
    super.dispose();
  }

  // 监听文本变化
  void _onTextChanged() {
    _noteInputCubit.updateText(widget.controller.text);
  }

  /// 保存笔记
  Future<void> _saveNote() async {
    await _noteInputCubit.saveNote();
    // 根据状态处理结果
    if (_noteInputCubit.state.status == NoteInputStatus.success) {
      widget.controller.clear();
      widget.onDismiss('');
    } else if (_noteInputCubit.state.status == NoteInputStatus.failure) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存笔记失败: ${_noteInputCubit.state.errorMessage}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 在光标处插入文本
  void _insertTextAtCursor(String textToInsert) {
    final currentText = widget.controller.text;
    final cursorPos = widget.controller.selection.baseOffset;
    if (cursorPos == -1) {
      widget.controller.text = currentText + textToInsert;
      widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: widget.controller.text.length));
      return;
    }
    final newText =
        '${currentText.substring(0, cursorPos)}$textToInsert${currentText.substring(cursorPos)}';
    widget.controller.text = newText;
    widget.controller.selection = TextSelection.fromPosition(
        TextPosition(offset: cursorPos + textToInsert.length));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _noteInputCubit,
      child: BlocListener<NoteInputCubit, NoteInputState>(
        listener: (context, state) {
          if (state.status == NoteInputStatus.success) {
            // 成功保存后更新控制器
            if (widget.controller.text != state.text) {
              widget.controller.text = state.text;
            }
          }
        },
        child: WillPopScope(
          onWillPop: () async {
            widget.onDismiss(widget.controller.text);
            return true;
          },
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).canvasColor,
                  border: Border.all(color: Colors.deepPurple.shade100, width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 输入区域
                    _buildInputArea(),
                    
                    const Divider(height: 1),
                    
                    // 工具栏
                    NoteInputToolbar(
                      onInsertText: _insertTextAtCursor,
                      onSaveNote: _saveNote,
                      tagButtonKey: _tagButtonKey,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建输入区域
  Widget _buildInputArea() {
    return SizedBox(
      height: 140,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            hintText: '✍️ 任何想法...',
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
} 