import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:record_app/features/note_detail/presentation/bloc/note_detail_bloc.dart';
import 'package:record_app/features/note_detail/presentation/bloc/note_detail_event.dart';
import 'package:record_app/features/note_detail/presentation/widgets/stats_and_tags_bar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record_app/features/note_detail/presentation/widgets/audio_recording_embed.dart';
import 'package:flutter/rendering.dart' show HitTestResult; // for hit testing
import 'package:record_app/core/widgets/image_context_menu.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:record_app/features/note_detail/presentation/widgets/embed_marker.dart';
import 'package:record_app/core/widgets/context_menu.dart';

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
  
  /// 是否处于编辑模式
  final bool isEditing;
  
  /// 点击进入编辑模式的回调
  final VoidCallback? onTapToEdit;
  
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
    this.isEditing = true,
    this.onTapToEdit,
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
    
    // 监听内容变化
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

  // 插入视频 - 公开方法，可以从外部调用
  Future<void> insertVideo() async {
    // 请求相册/视频权限（与图片相同）
    final status = await Permission.photos.request();
    if (status.isGranted) {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        await _copyVideoAndInsertToEditor(video);
      }
    } else if (status.isDenied || status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要相册权限才能选择视频')),
        );
      }
    }
  }

  // 插入音频录音 - 公开方法，可以从外部调用
  Future<void> insertAudioRecording() async {
    // 请求麦克风权限
    final status = await Permission.microphone.request();

    if (status.isGranted) {
      try {
        // 直接在当前光标位置插入一个新的录音嵌入块（处于录音状态）
        final audioEmbed = AudioRecordingBlockEmbed.createNew();
        
        // 在当前光标位置插入音频嵌入
        final index = _controller.selection.baseOffset;
        final isSelectionValid = index >= 0 && index < _controller.document.length;
        final offset = isSelectionValid ? index : _controller.document.length;
        
        // 创建一个全局变量，用于跟踪当前的录音嵌入块
        _controller.document.insert(offset, audioEmbed);
        // 始终在录音嵌入后插入换行符，确保立即渲染
        _controller.document.insert(offset + 1, '\n');
        // 移动光标到嵌入后的下一行
        _controller.updateSelection(
          TextSelection.collapsed(offset: offset + 2),
          ChangeSource.local,
        );
      } catch (e) {
        debugPrint('插入音频嵌入失败: $e');
        // 回退到添加到末尾
        try {
          _controller.document.insert(_controller.document.length, AudioRecordingBlockEmbed.createNew());
          _controller.document.insert(_controller.document.length, '\n');
        } catch (e2) {
          debugPrint('回退插入音频嵌入也失败: $e2');
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要麦克风权限才能录音')),
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

  // 复制视频并插入到编辑器
  Future<void> _copyVideoAndInsertToEditor(XFile videoFile) async {
    final documents = await getApplicationDocumentsDirectory();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(videoFile.path)}';
    final String newPath = '${documents.path}/$fileName';
    await videoFile.saveTo(newPath);

    try {
      final index = _controller.selection.baseOffset;
      final isSelectionValid = index >= 0 && index < _controller.document.length;
      final offset = isSelectionValid ? index : _controller.document.length;
      _controller.document.insert(offset, BlockEmbed.video(newPath));
      if (offset < _controller.document.length - 1 &&
          _controller.document.getPlainText(offset + 1, offset + 2) != '\n') {
        _controller.document.insert(offset + 1, '\n');
      }
    } catch (e) {
      debugPrint('插入视频失败: $e');
      try {
        _controller.document.insert(_controller.document.length, BlockEmbed.video(newPath));
        _controller.document.insert(_controller.document.length, '\n');
      } catch (e2) {
        debugPrint('回退插入视频也失败: $e2');
      }
    }
  }

  // 统一选择媒体（图片或视频）
  Future<void> insertMedia() async {
    if (!mounted) return;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择要插入的媒体'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'image'),
            child: const Text('图片'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'video'),
            child: const Text('视频'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'audio'),
            child: const Text('录音'),
          ),
        ],
      ),
    );
    if (result == 'image') {
      await insertImage();
    } else if (result == 'video') {
      await insertVideo();
    } else if (result == 'audio') {
      await insertAudioRecording();
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
    // 设置编辑器的只读状态
    _controller.readOnly = !widget.isEditing;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题输入框 - 在编辑模式下可以编辑，浏览模式下只显示
          widget.isEditing 
              ? TextField(
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
                )
              : Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    widget.titleController.text.isEmpty ? '无标题' : widget.titleController.text,
                    style: const TextStyle(
                      fontSize: 20, 
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                      color: Colors.black87,
                    ),
                  ),
                ),
          
          // 字数统计和标签显示栏
          Padding(
            padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
            child: StatsAndTagsBar(
              noteId: widget.noteId,
              content: _controller.document.toPlainText(),
              isEditing: widget.isEditing,
              onTagRemoved: widget.isEditing ? widget.onTagRemoved : null,
            ),
          ),
          
          // 编辑器区域 - 根据模式切换readOnly状态
          Expanded(
            child: Stack(
              children: [
                QuillEditor.basic(
                  controller: _controller,
                  focusNode: _editorFocusNode,
                  scrollController: _scrollController,
                  config: QuillEditorConfig(
                    placeholder: widget.isEditing ? '开始输入...' : '',
                    scrollable: true,
                    autoFocus: widget.isEditing,
                    expands: true,
                    padding: EdgeInsets.zero,
                    embedBuilders: [
                      CustomImageEmbedBuilder(), 
                      CustomVideoEmbedBuilder(),
                      AudioRecordingEmbedBuilder(),
                    ],
                    detectWordBoundary: true,
                    enableSelectionToolbar: widget.isEditing,
                    showCursor: widget.isEditing,
                  ),
                ),
                if (!widget.isEditing && widget.onTapToEdit != null)
                  Positioned.fill(
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (event) {
                        if (!_isEmbedAtPosition(event.position)) {
                          widget.onTapToEdit!();
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
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

  // 判断点击位置是否位于图片/视频/录音等自定义组件上，而非纯文本
  bool _isEmbedAtPosition(Offset globalPosition) {
    final result = HitTestResult();
    WidgetsBinding.instance.hitTest(result, globalPosition);

    for (final entry in result.path) {
      final target = entry.target;
      // 如命中自定义 QuillEmbedMarker，则视为 embed
      if (target is QuillEmbedMarkerRenderBox) {
        return true;
      }
    }
    return false;
  }

  // 显示视频/音频通用菜单
  void _deleteEmbed(EmbedContext embedContext) {
    final offset = embedContext.node.documentOffset;
    _controller.replaceText(offset, 1, '', null);
  }

  void _showMediaContextMenu({
    required BuildContext context,
    required Offset position,
    required String path,
    required EmbedContext embedContext,
    required bool isEditing,
    bool isVideo = true,
  }) {
    final items = <ContextMenuItem>[
      ContextMenuItem(title: '复制', onTap: () => Clipboard.setData(ClipboardData(text: path))),
      ContextMenuItem(title: '分享', onTap: () => Share.share(path)),
      if (isEditing)
        ContextMenuItem(title: '删除', onTap: () => _deleteEmbed(embedContext), isDestructive: true),
    ];

    CommonContextMenu.show(context: context, position: position, items: items);
  }
}

/// 录音叠加组件 - 用于显示录音界面
class _AudioRecordingOverlay extends StatelessWidget {
  final Function(String path, String duration, String timestamp) onRecordingComplete;
  
  const _AudioRecordingOverlay({
    required this.onRecordingComplete,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      height: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '录制语音',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: AudioRecordingWidget(
              onRecordingComplete: (path, duration, timestamp) {
                // 通知父组件录音已完成
                onRecordingComplete(path, duration, timestamp);
                // 关闭底部面板
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 自定义图片嵌入构建器
class CustomImageEmbedBuilder extends EmbedBuilder {
  @override
  String get key => BlockEmbed.imageType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final imageUrl = embedContext.node.value.data;
    return QuillEmbedMarker(
      child: GestureDetector(
        onLongPressStart: (details) {
          bool isEditing = false;
          try {
            final state = context.findAncestorStateOfType<_QuillEditorWidgetState>();
            isEditing = state?.widget.isEditing ?? false;
          } catch (_) {}
          _showImageContextMenu(
            context,
            imageUrl,
            details.globalPosition,
            embedContext,
            isEditing,
          );
        },
        child: Image.file(
          File(imageUrl),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 200,
              height: 100,
              color: Colors.grey[300],
              child: const Center(child: Text('图片加载失败')),
            );
          },
        ),
      ),
    );
  }

  // 显示图片上下文菜单
  void _showImageContextMenu(
    BuildContext context, 
    String path, 
    Offset tapPosition, 
    EmbedContext embedContext,
    bool isEditing
  ) {
    ImageContextMenu.show(
      context: context,
      position: tapPosition,
      onThumbnailMode: () {
        // 切换缩略图模式
        context.read<NoteDetailBloc>().add(const NoteDetailToggleThumbnailMode());
      },
      thumbnailModeText: "大图模式", // 显示为"大图模式"
      onCopy: () => _copyImageToClipboard(context, path),
      onShare: () => _shareImage(context, path),
      onSave: () => _saveImage(context, path),
      onDelete: isEditing ? () => _deleteImage(context, embedContext, path) : null,
    );
  }
  
  // 删除图片
  void _deleteImage(BuildContext context, EmbedContext embedContext, String path) {
    try {
      // 尝试从父级组件中获取QuillController
      final state = context.findAncestorStateOfType<_QuillEditorWidgetState>();
      if (state != null) {
        // 从_QuillEditorWidgetState获取controller
        final controller = state.controller;
        
        // 删除图片嵌入
        final offset = embedContext.node.documentOffset;
        controller.replaceText(offset, 1, '', null);
        
        // 通知删除图片
        if (state.widget.onDeleteImage != null) {
          state.widget.onDeleteImage!(path);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除图片失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  // 复制图片到剪贴板
  Future<void> _copyImageToClipboard(BuildContext context, String path) async {
    try {
      await Clipboard.setData(ClipboardData(text: path));
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('图片路径已复制到剪贴板'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('复制失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  // 分享图片
  Future<void> _shareImage(BuildContext context, String path) async {
    try {
      await Share.share(path, subject: '分享图片');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('分享失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  // 保存图片（这里只显示提示，因为图片已经在本地了）
  void _saveImage(BuildContext context, String path) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('图片已保存在: $path'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// 自定义视频嵌入构建器
class CustomVideoEmbedBuilder extends EmbedBuilder {
  @override
  String get key => BlockEmbed.videoType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final videoPath = embedContext.node.value.data;
    return QuillEmbedMarker(
      child: GestureDetector(
        onLongPressStart: (details) {
          bool isEditing = false;
          try {
            final state = context.findAncestorStateOfType<_QuillEditorWidgetState>();
            isEditing = state?.widget.isEditing ?? false;
            state?._showMediaContextMenu(
              context: context,
              position: details.globalPosition,
              path: videoPath,
              embedContext: embedContext,
              isEditing: isEditing,
              isVideo: true,
            );
          } catch (_) {}
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: _VideoPlayerWidget(videoPath: videoPath),
        ),
      ),
    );
  }
}

class _VideoPlayerWidget extends StatefulWidget {
  final String videoPath;
  const _VideoPlayerWidget({required this.videoPath});

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  late VideoPlayerController _controller;
  Future<void>? _initFuture;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath));
    _initFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done || !_controller.value.isInitialized) {
          // 如果Future未完成，或已完成但控制器未成功初始化，显示加载或错误状态
          if (snapshot.hasError) {
            return Container(
              color: Colors.black,
              height: 150,
              child: Center(
                child: Text('视频加载失败: ${snapshot.error}', style: const TextStyle(color: Colors.white)),
              ),
            );
          }
          return const SizedBox(
            width: 200,
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        // 只有当Future完成且控制器成功初始化后才构建播放器
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              _controller.value.isPlaying ? _controller.pause() : _controller.play();
            });
          },
          child: AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(_controller),
                Icon(
                  _controller.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
                  size: 48,
                  color: Colors.white70,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}