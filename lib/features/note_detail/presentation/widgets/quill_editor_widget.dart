import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/features/note_detail/presentation/bloc/note_detail_bloc.dart';
import 'package:record/features/note_detail/presentation/bloc/note_detail_event.dart';
import 'package:record/features/note_detail/presentation/widgets/stats_and_tags_bar.dart';

/// 基于Flutter Quill的笔记编辑器组件
class QuillEditorWidget extends StatefulWidget {
  /// 标题控制器
  final TextEditingController titleController;
  
  /// 内容
  final String content;
  
  /// 内容焦点节点
  final FocusNode focusNode;
  
  /// 笔记ID
  final int noteId;
  
  /// 标题变化回调
  final Function(String) onTitleChanged;
  
  /// 内容变化回调
  final Function(String) onContentChanged;
  
  /// 删除图片回调
  final Function(String)? onDeleteImage;

  /// 删除标签回调
  final Function(String)? onTagRemoved;
  
  /// 是否启用小图模式
  final bool thumbnailMode;

  const QuillEditorWidget({
    super.key,
    required this.titleController,
    required this.content,
    required this.focusNode,
    required this.noteId,
    required this.onTitleChanged,
    required this.onContentChanged,
    this.onDeleteImage,
    this.onTagRemoved,
    this.thumbnailMode = false,
  });

  @override
  State<QuillEditorWidget> createState() => _QuillEditorWidgetState();
}

class _QuillEditorWidgetState extends State<QuillEditorWidget> {
  late quill.QuillController _controller;
  final ImagePicker _picker = ImagePicker();
  final FocusNode _editorFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  
  // 创建一个内容控制器来直接控制TextField
  late TextEditingController _textEditingController;

  @override
  void initState() {
    super.initState();
    
    // 初始化文本编辑控制器
    _textEditingController = TextEditingController(text: widget.content);
    
    // 初始化QuillController
    if (widget.content.isNotEmpty) {
      // 尝试将Markdown内容转换为Quill Delta格式
      try {
        final document = _convertMarkdownToQuillDocument(widget.content);
        _controller = quill.QuillController(
          document: document,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (e) {
        // 如果转换失败，使用空文档
        _controller = quill.QuillController.basic();
        _controller.document.insert(0, widget.content);
      }
    } else {
      _controller = quill.QuillController.basic();
    }
    
    // 监听内容变化
    _controller.addListener(_onTextChanged);
    
    // 监听TextField内容变化
    _textEditingController.addListener(() {
      widget.onContentChanged(_textEditingController.text);
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _textEditingController.dispose();
    _editorFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  // 监听Quill编辑器内容变化
  void _onTextChanged() {
    final plainText = _controller.document.toPlainText();
    widget.onContentChanged(plainText);
  }
  
  // 将Markdown转换为Quill Document (简单实现)
  quill.Document _convertMarkdownToQuillDocument(String markdown) {
    // 创建一个基本文档
    final doc = quill.Document.fromJson([
      {"insert": markdown}
    ]);
    
    return doc;
  }
  
  // 插入图片 - 公开方法，可以从外部调用
  Future<void> insertImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await _copyImageAndInsertToEditor(image);
    }
  }

  // 复制图片并插入到编辑器
  Future<void> _copyImageAndInsertToEditor(XFile imageFile) async {
    final documents = await getApplicationDocumentsDirectory();
    final fileName = p.basename(imageFile.path);
    final String newPath = '${documents.path}/$fileName';

    // 保存文件
    await imageFile.saveTo(newPath);

    // 添加到新图片路径列表（如果父组件需要）
    if (widget.onDeleteImage != null) {
      context.read<NoteDetailBloc>().add(NoteDetailUpdateImages(
        newImagePaths: [newPath],
        deletedImagePaths: [],
      ));
    }

    try {
      // 在当前光标位置插入图片
      // 使用markdown格式的图片语法，因为我们最终存储的是markdown内容
      final markdownImage = '![image]($newPath)';
      
      // 获取当前光标位置
      final cursorPosition = widget.focusNode.hasFocus 
          ? _textEditingController.selection.baseOffset 
          : _textEditingController.text.length;
      
      if (cursorPosition >= 0) {
        final currentText = _textEditingController.text;
        
        // 在光标位置插入markdown格式的图片
        final newText = currentText.substring(0, cursorPosition) + 
                      markdownImage + 
                      currentText.substring(cursorPosition);
        
        // 更新编辑器内容
        _textEditingController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: cursorPosition + markdownImage.length),
        );
        
        // 通知内容变化
        widget.onContentChanged(newText);
      } else {
        // 如果没有找到有效的光标位置，添加到内容末尾
        final newText = '${_textEditingController.text}\n$markdownImage';
        _textEditingController.text = newText;
        widget.onContentChanged(newText);
      }
    } catch (e) {
      // 在发生错误时回退到添加到末尾
      final newText = '${_textEditingController.text}\n![image]($newPath)';
      _textEditingController.text = newText;
      widget.onContentChanged(newText);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题输入框
        TextField(
          controller: widget.titleController,
          decoration: const InputDecoration(
            hintText: '标题',
            hintStyle: TextStyle(color: Colors.grey),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          style: const TextStyle(
            fontSize: 20, 
            fontWeight: FontWeight.bold,
            height: 1.5,
            color: Colors.black87,
          ),
          onChanged: widget.onTitleChanged,
        ),
        
        // 字数统计和标签显示栏
        Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
          child: StatsAndTagsBar(
            noteId: widget.noteId,
            content: _textEditingController.text,
            isEditing: true,
            onTagRemoved: widget.onTagRemoved,
          ),
        ),
        
        // 编辑器区域 - 使用Expanded填充剩余空间
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _textEditingController,
              focusNode: widget.focusNode,
              maxLines: null, 
              decoration: const InputDecoration(border: InputBorder.none),
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.black87,
              ),
              onChanged: widget.onContentChanged,
            ),
          ),
        ),
      ],
    );
  }
  
  // 辅助方法：在选中文本两端插入格式标记（如**bold**）- 公开方法，可以从外部调用
  void insertFormatting(String prefix, String suffix) {
    final TextEditingValue currentValue = _textEditingController.value;
    final text = currentValue.text;
    final selection = currentValue.selection;
    
    if (selection.isCollapsed) {
      // 光标位置，没有选中文本
      final newText = text.substring(0, selection.baseOffset) + 
                      prefix + suffix + 
                      text.substring(selection.baseOffset);
      
      _textEditingController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.baseOffset + prefix.length
        ),
      );
    } else {
      // 选中了文本
      final selectedText = text.substring(selection.baseOffset, selection.extentOffset);
      final newText = text.substring(0, selection.baseOffset) + 
                     prefix + selectedText + suffix + 
                     text.substring(selection.extentOffset);
      
      _textEditingController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.baseOffset + prefix.length + selectedText.length + suffix.length
        ),
      );
    }
    
    widget.onContentChanged(_textEditingController.text);
  }
  
  // 辅助方法：在当前行或选中行前插入列表标记 - 公开方法，可以从外部调用
  void insertList(String marker) {
    final TextEditingValue currentValue = _textEditingController.value;
    final text = currentValue.text;
    final selection = currentValue.selection;
    
    // 获取当前行
    final lineStart = text.lastIndexOf('\n', selection.baseOffset) + 1;
    final lineEnd = text.indexOf('\n', selection.baseOffset);
    final currentLine = lineEnd >= 0 ? 
                       text.substring(lineStart, lineEnd) : 
                       text.substring(lineStart);
    
    // 在行首添加标记
    final newText = text.substring(0, lineStart) + 
                   marker + currentLine + 
                   (lineEnd >= 0 ? text.substring(lineEnd) : '');
    
    _textEditingController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: lineStart + marker.length + currentLine.length
      ),
    );
    
    widget.onContentChanged(_textEditingController.text);
  }
} 