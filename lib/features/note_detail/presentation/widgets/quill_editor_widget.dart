import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/features/note_detail/presentation/bloc/note_detail_bloc.dart';
import 'package:record/features/note_detail/presentation/bloc/note_detail_event.dart';
import 'package:record/features/note_detail/presentation/widgets/stats_and_tags_bar.dart';
import 'package:permission_handler/permission_handler.dart';

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
  
  /// 获取编辑器控制器
  static QuillController? getController(GlobalKey<State<QuillEditorWidget>> key) {
    final state = key.currentState;
    if (state != null) {
      // 使用private cast
      return (state as dynamic).controller as QuillController?;
    }
    return null;
  }

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
  late QuillController _controller;
  final ImagePicker _picker = ImagePicker();
  final FocusNode _editorFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // 提供一个getter来访问QuillController
  QuillController get controller => _controller;

  @override
  void initState() {
    super.initState();
    
    // 初始化QuillController
    if (widget.content.isNotEmpty) {
      // 尝试将内容转换为Quill Delta格式
      try {
        final document = _convertContentToQuillDocument(widget.content);
        _controller = QuillController(
          document: document,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (e) {
        // 如果转换失败，使用空文档
        _controller = QuillController.basic();
      }
    } else {
      _controller = QuillController.basic();
    }
    
    // 监听内容变化，但不使用自动恢复光标位置的逻辑
    _controller.addListener(_onTextChanged);
    
    // 确保编辑器在初始化后获得焦点，并将光标移到末尾
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _editorFocusNode.requestFocus();
        // 将光标移到文档末尾
        _controller.updateSelection(
          TextSelection.collapsed(offset: _controller.document.length),
          ChangeSource.local
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _editorFocusNode.dispose();
    _scrollController.dispose();
    // 取消防抖计时器
    _debounceTimer?.cancel();
    super.dispose();
  }
  
  // 监听Quill编辑器内容变化
  void _onTextChanged() {
    // 传递Delta JSON数据给回调函数，而不是纯文本
    final String deltaJson = getDocumentJson();
    widget.onContentChanged(deltaJson);
    
    // 确保在内容变化后，编辑器仍然保持焦点
    if (!_editorFocusNode.hasFocus && mounted) {
      _editorFocusNode.requestFocus();
    }
  }
  
  // 将内容转换为Quill Document
  Document _convertContentToQuillDocument(String content) {
    // 尝试解析为JSON Delta格式
    try {
      // 如果内容已经是Delta JSON格式
      final dynamic jsonData = jsonDecode(content);
      return Document.fromJson(jsonData);
    } catch (e) {
      // 如果不是JSON格式，检查是否包含Markdown图片语法
      final String processedContent = _convertMarkdownImagesToEmbeds(content);
      return Document.fromJson([
        {"insert": processedContent}
      ]);
    }
  }
  
  // 将Markdown格式的图片语法转换为Quill嵌入图片
  String _convertMarkdownImagesToEmbeds(String content) {
    // 创建一个新的文档
    final Document tempDoc = Document();
    
    // 正则表达式匹配Markdown图片语法: ![alt](url)
    final RegExp imgRegex = RegExp(r'!\[(.*?)\]\((.*?)\)');
    
    // 找到所有匹配项
    final matches = imgRegex.allMatches(content);
    
    // 如果没有匹配项，直接返回原内容
    if (matches.isEmpty) {
      return content;
    }
    
    // 处理所有匹配项
    int lastEnd = 0;
    for (final match in matches) {
      // 添加图片前的文本
      if (match.start > lastEnd) {
        tempDoc.insert(tempDoc.length, content.substring(lastEnd, match.start));
      }
      
      // 提取图片URL
      final String imageUrl = match.group(2) ?? '';
      
      // 添加图片嵌入
      if (imageUrl.isNotEmpty) {
        tempDoc.insert(tempDoc.length, BlockEmbed.image(imageUrl));
        tempDoc.insert(tempDoc.length, '\n');
      }
      
      lastEnd = match.end;
    }
    
    // 添加最后一段文本
    if (lastEnd < content.length) {
      tempDoc.insert(tempDoc.length, content.substring(lastEnd));
    }
    
    // 返回处理后的内容为Delta JSON
    return jsonEncode(tempDoc.toDelta().toJson());
  }
  
  // 插入图片 - 公开方法，可以从外部调用
  Future<void> insertImage() async {
    // 请求相册权限
    final status = await Permission.photos.request();

    // 检查权限状态
    if (status.isGranted) {
      // 权限被授予，打开相册
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        await _copyImageAndInsertToEditor(image);
      }
    } else if (status.isDenied || status.isPermanentlyDenied) {
      // 权限被拒绝，给用户一个提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要相册权限才能选择图片')),
        );
      }
    }
  }

  // 复制图片并插入到编辑器
  Future<void> _copyImageAndInsertToEditor(XFile imageFile) async {
    final documents = await getApplicationDocumentsDirectory();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(imageFile.path)}';
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
      final index = _controller.selection.baseOffset;
      final isSelectionValid = index >= 0 && index < _controller.document.length;
      final offset = isSelectionValid ? index : _controller.document.length;
      
      // 使用Quill的图片嵌入格式
      _controller.document.insert(offset, BlockEmbed.image(newPath));
      
      // 确保图片后有换行符
      if (offset < _controller.document.length - 1 && 
          _controller.document.getPlainText(offset + 1, offset + 2) != '\n') {
        _controller.document.insert(offset + 1, '\n');
      }
    } catch (e) {
      debugPrint('插入图片失败: $e');
      // 在发生错误时回退到添加到末尾
      try {
        _controller.document.insert(_controller.document.length, BlockEmbed.image(newPath));
        _controller.document.insert(_controller.document.length, '\n');
      } catch (e2) {
        debugPrint('回退插入图片也失败: $e2');
      }
    }
  }

  // 用于防抖处理的计时器
  Timer? _debounceTimer;
  
  // 防抖处理函数，避免频繁触发内容更新
  void _debounce(VoidCallback callback, {Duration duration = const Duration(milliseconds: 300)}) {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }
    _debounceTimer = Timer(duration, callback);
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
          onChanged: (value) {
            // 使用防抖处理标题更新，避免频繁触发
            _debounce(() {
              widget.onTitleChanged(value);
            });
          },
        ),
        
        // 字数统计和标签显示栏
        Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
          child: StatsAndTagsBar(
            noteId: widget.noteId,
            content: _controller.document.toPlainText(),
            isEditing: true,
            onTagRemoved: widget.onTagRemoved,
          ),
        ),
        
        // 编辑器区域 - 移除了内置工具栏，直接显示编辑器
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(4),
            ),
            child: QuillEditor.basic(
              controller: _controller,
              focusNode: _editorFocusNode,
              scrollController: _scrollController,
              config: QuillEditorConfig(
                placeholder: '开始输入...',
                scrollable: true,
                autoFocus: true,
                expands: true,
                padding: const EdgeInsets.all(8.0),
                embedBuilders: [CustomImageEmbedBuilder()],
                detectWordBoundary: true,
                enableSelectionToolbar: true,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  // 辅助方法：在选中文本两端插入格式标记 - 公开方法，可以从外部调用
  void insertFormatting(String prefix, String suffix) {
    final selection = _controller.selection;
    
    if (selection.isCollapsed) {
      // 光标位置，没有选中文本
      _controller.document.insert(selection.baseOffset, prefix + suffix);
      _controller.updateSelection(
        TextSelection.collapsed(offset: selection.baseOffset + prefix.length),
        ChangeSource.local
      );
    } else {
      // 选中了文本
      final selectedText = _controller.document.getPlainText(selection.start, selection.end);
      _controller.replaceText(
        selection.baseOffset, 
        selection.extentOffset - selection.baseOffset, 
        prefix + selectedText + suffix, 
        null
      );
      _controller.updateSelection(
        TextSelection.collapsed(offset: selection.baseOffset + prefix.length + selectedText.length + suffix.length),
        ChangeSource.local
      );
    }
  }
  
  // 辅助方法：在当前行或选中行前插入列表标记 - 公开方法，可以从外部调用
  void insertList(String marker) {
    final selection = _controller.selection;
    final plainText = _controller.document.toPlainText();
    
    // 获取当前行
    final lineStart = plainText.lastIndexOf('\n', selection.baseOffset) + 1;
    final lineEnd = plainText.indexOf('\n', selection.baseOffset);
    final currentLine = lineEnd >= 0 ? 
                       plainText.substring(lineStart, lineEnd) : 
                       plainText.substring(lineStart);
    
    // 在行首添加标记
    _controller.replaceText(
      lineStart, 
      0, 
      marker, 
      null
    );
  }
  
  // 使用Quill格式化API应用格式 - 公开方法，可以从外部调用
  void applyFormat(Attribute attribute) {
    final selection = _controller.selection;
    if (selection.isCollapsed) {
      // 如果没有选中文本，设置格式状态
      _controller.formatSelection(attribute);
    } else {
      // 如果选中了文本，应用格式
      _controller.formatText(
        selection.baseOffset,
        selection.extentOffset - selection.baseOffset,
        attribute,
      );
    }
  }
  
  // 获取当前文档的Delta JSON - 公开方法，可以从外部调用
  String getDocumentJson() {
    return jsonEncode(_controller.document.toDelta().toJson());
  }

  // 处理光标位置变化
  void _handleCursorPositionChange(int newPosition) {
    if (newPosition >= 0 && newPosition <= _controller.document.length && mounted) {
      _controller.updateSelection(
        TextSelection.collapsed(offset: newPosition),
        ChangeSource.local
      );
    }
  }
}

/// 自定义图片嵌入构建器
class CustomImageEmbedBuilder extends EmbedBuilder {
  @override
  String get key => BlockEmbed.imageType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final imageUrl = embedContext.node.value.data;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Image.file(
          File(imageUrl),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 200,
              height: 100,
              color: Colors.grey[300],
              child: const Center(
                child: Text('图片加载失败'),
              ),
            );
          },
        ),
      ),
    );
  }
} 