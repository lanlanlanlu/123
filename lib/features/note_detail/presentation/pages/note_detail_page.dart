import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/data/database/database.dart';
import 'package:drift/drift.dart' as d;
import 'package:record/core/utils/date_extensions.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/data/repository/index.dart';
import 'package:record/features/note_detail/presentation/bloc/note_detail_bloc.dart';
import 'package:record/features/note_detail/presentation/bloc/note_detail_event.dart';
import 'package:record/features/note_detail/presentation/bloc/note_detail_state.dart'; 
import 'package:record/features/tags/presentation/pages/tag_detail_page.dart';
import 'package:record/core/widgets/interactive_text.dart';
import 'package:permission_handler/permission_handler.dart';

// 导入重构后的组件
import 'package:record/features/note_detail/presentation/widgets/note_editor_widget.dart';
import 'package:record/features/note_detail/presentation/widgets/note_preview_widget.dart';
import 'package:record/features/note_detail/presentation/widgets/note_reading_widget.dart';
import 'package:record/features/note_detail/presentation/widgets/note_image_grid.dart';
import 'package:record/features/note_detail/presentation/widgets/note_edit_actions_bar.dart';
import 'package:record/features/note_detail/presentation/widgets/note_utils.dart';

class NoteDetailPage extends StatelessWidget {
  final Note note;
  const NoteDetailPage({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NoteDetailBloc(
        notesRepository: context.read<NotesRepository>(),
        tagsRepository: context.read<TagsRepository>(),
      )..add(NoteDetailLoadNote(note.id)),
      child: NoteDetailView(initialNote: note),
    );
  }
}

class NoteDetailView extends StatefulWidget {
  final Note initialNote;
  const NoteDetailView({super.key, required this.initialNote});

  @override
  State<NoteDetailView> createState() => _NoteDetailViewState();
}

class _NoteDetailViewState extends State<NoteDetailView> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late TextEditingController _textController;
  late TextEditingController _titleController;
  final FocusNode _focusNode = FocusNode();

  // 编辑历史管理
  final List<String> _undoHistory = [];
  final List<String> _redoHistory = [];
  String _lastText = '';
  bool _isUndoRedo = false; // 标记当前变化是否由撤销/重做操作引起
  bool _isUpdatingFromTitle = false; // 标记是否由标题更新引起的文本变化

  final List<String> _newImagePaths = [];
  final List<String> _deletedImagePaths = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // 完全分离标题和内容，内容不再包含标题
    _textController = TextEditingController(text: widget.initialNote.content);
    _titleController = TextEditingController(text: widget.initialNote.title);
    _lastText = widget.initialNote.content; // 初始文本
    
    // 添加文本控制器监听
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    // 移除监听器
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _titleController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // 处理文本变化
  void _onTextChanged() {
    // 如果当前文本变化是由撤销/重做操作或标题更新引起的，不记录历史
    if (_isUndoRedo || _isUpdatingFromTitle) {
      _isUndoRedo = false;
      _isUpdatingFromTitle = false;
      return;
    }
    
    final currentText = _textController.text;
    if (_lastText != currentText) {
      // 添加到撤销历史
      _undoHistory.add(_lastText);
      // 清空重做历史
      _redoHistory.clear();
      // 更新最后的文本
      _lastText = currentText;
      
      // 删除自动更新标题的行为，改为让用户自行编辑标题
      // 标题和内容完全分离
      
      // 通知BLoC内容已更新
      context.read<NoteDetailBloc>().add(NoteDetailUpdateContent(currentText));
      
      // 刷新UI以更新按钮状态和字数统计
      setState(() {});
    }
  }
  
  // 从标题更新内容 - 修改为不再将标题添加到正文中，标题单独显示
  void _updateContentFromTitle(String title) {
    _isUpdatingFromTitle = true;
    
    // 通知BLoC标题已更新
    context.read<NoteDetailBloc>().add(NoteDetailUpdateTitle(title));
    
    // 添加到撤销历史
    _undoHistory.add(_lastText);
    // 清空重做历史
    _redoHistory.clear();
    // 更新最后的文本
    _lastText = _textController.text;
    
    // 刷新UI以更新按钮状态和字数统计
    setState(() {});
  }

  void _switchToEditMode() {
    // 通知BLoC切换到编辑模式
    context.read<NoteDetailBloc>().add(const NoteDetailToggleEditMode());
    
    // 初始化文本和历史
    final state = context.read<NoteDetailBloc>().state;
    if (state is NoteDetailLoaded) {
      // 从数据库获取内容
      _textController.text = state.note.content;
      // 设置标题（标题现在与内容分离）
      _titleController.text = state.note.title;
      _lastText = state.note.content;
      _undoHistory.clear();
      _redoHistory.clear();
      
      Future.delayed(const Duration(milliseconds: 100), () {
        if(mounted) FocusScope.of(context).requestFocus(_focusNode);
      });
    }
  }

  Future<void> _saveNote() async {
    // 确保newImagePaths中没有重复项
    final Set<String> uniqueNewPaths = Set<String>.from(_newImagePaths);
    final uniqueDeletedPaths = Set<String>.from(_deletedImagePaths);
    
    // 先处理图片更新
    context.read<NoteDetailBloc>().add(NoteDetailUpdateImages(
      newImagePaths: uniqueNewPaths.toList(),
      deletedImagePaths: uniqueDeletedPaths.toList(),
    ));
    
    // 通知BLoC保存笔记
    context.read<NoteDetailBloc>().add(const NoteDetailSaveNote());
    
    // 清理历史和图片状态
    _undoHistory.clear();
    _redoHistory.clear();
    _newImagePaths.clear();
    _deletedImagePaths.clear();
  }

  // 在选择图片前，先请求权限
  Future<void> _pickImageFromGallery() async {
    // 1. 请求相册权限
    final status = await Permission.photos.request();

    // 2. 检查权限状态
    if (status.isGranted) {
      // 权限被授予，打开相册
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        await _copyImageAndInsertAtCursor(image);
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

  // 修改为在光标处插入图片
  Future<void> _copyImageAndInsertAtCursor(XFile imageFile) async {
    final documents = await getApplicationDocumentsDirectory();
    final fileName = p.basename(imageFile.path);
    // 1. 先构建好我们要保存的路径
    final String newPath = '${documents.path}/$fileName';

    // 2. 使用这个路径来保存文件
    await imageFile.saveTo(newPath);

    // 3. 添加到新图片路径列表中
    setState(() {
      _newImagePaths.add(newPath);
    });
    
    // 4. 在光标处插入Markdown图片语法
    // 使用原始尺寸的图片，不压缩或裁剪
    final imageMarkdown = '![image]($newPath)';
    _insertTextAtCursor(imageMarkdown);
    
    // 图片更新会在_saveNote方法中进行
  }

  // 一个在光标处插入文本的通用方法
  void _insertTextAtCursor(String textToInsert) {
    final currentText = _textController.text;
    final cursorPos = _textController.selection.baseOffset;
    if (cursorPos == -1) {
      _textController.text = currentText + textToInsert;
      _textController.selection = TextSelection.fromPosition(TextPosition(offset: _textController.text.length));
      return;
    }
    final newText = '${currentText.substring(0, cursorPos)}$textToInsert${currentText.substring(cursorPos)}';
    _textController.text = newText;
    _textController.selection = TextSelection.fromPosition(TextPosition(offset: cursorPos + textToInsert.length));
  }

  // 处理删除图片
  void _handleDeleteImage(String path) {
    setState(() {
      if (_newImagePaths.contains(path)) {
        _newImagePaths.remove(path);
      } else {
        _deletedImagePaths.add(path);
      }
    });
    
    // 不再立即通知Bloc，避免UI渲染问题
    // 实际的图片更新会在_saveNote方法中进行
  }

  // 处理删除标签
  void _handleTagRemoved(String tagName) async {

    // 查找并删除标签
    final text = _textController.text;
    
    // 使用更精确的正则表达式匹配标签
    // 处理多种情况：行首、空格后、标点符号后等
    String newText = text;
    
    // 1. 处理行首的标签
    final startPattern = RegExp(r'^#' + RegExp.escape(tagName) + r'(?=\s|$)');
    newText = newText.replaceAll(startPattern, '');
    
    // 2. 处理空格后的标签
    final spacePattern = RegExp(r'(\s)#' + RegExp.escape(tagName) + r'(?=\s|$)');
    newText = newText.replaceAll(spacePattern, r'$1');
    
    // 3. 处理特殊情况：标签在行中间或结尾
    final anywherePattern = RegExp(r'#' + RegExp.escape(tagName) + r'\b');
    if (newText.contains(anywherePattern)) {
      newText = newText.replaceAll(anywherePattern, '');
    }
    
    
    // 更新文本控制器
    setState(() {
      _textController.text = newText;
      _lastText = newText;
    });
    
    // 通知BLoC内容已更新
    context.read<NoteDetailBloc>().add(NoteDetailUpdateContent(newText));
    
    // 从数据库中查找并删除标签关联
    
      final state = context.read<NoteDetailBloc>().state;
      if (state is NoteDetailLoaded) {
        final noteId = state.note.id;
        final tagsRepository = context.read<TagsRepository>();
        
        // 获取当前笔记的所有标签
        final tags = await tagsRepository.getTagsForNote(noteId);
        
        // 查找匹配的标签
        for (final tag in tags) {
          if (tag.name == tagName) {
            // 从数据库中删除标签关联
            await tagsRepository.removeTagFromNote(noteId, tag.id);
            
            // 通知Bloc标签已删除
            context.read<NoteDetailBloc>().add(NoteDetailRemoveTag(tag.id));
            break;
          }
        }
      }
    
    
  }

  List<Widget> _buildAppBarActions(NoteDetailLoaded state) {
    if (state.editMode == NoteEditMode.editing || state.editMode == NoteEditMode.previewing) {
      if (state.editMode == NoteEditMode.previewing) {
        // 预览模式 - 显示编辑按钮
        return [
          IconButton(
            onPressed: () {
              // 确保在切换到编辑模式时保留预览前的内容
              _textController.text = _lastText;
              // 同步更新到Bloc状态以保持草稿
              context.read<NoteDetailBloc>().add(NoteDetailUpdateContent(_lastText));
              // 切换模式
              context.read<NoteDetailBloc>().add(const NoteDetailToggleEditMode());
              // 延迟一下再设置焦点，确保UI已经切换到编辑模式
              Future.delayed(const Duration(milliseconds: 100), () {
                if(mounted) FocusScope.of(context).requestFocus(_focusNode);
              });
            },
            icon: const Icon(Icons.edit),
            tooltip: '继续编辑',
          ),
        ];
      } else {
        // 编辑模式 - 显示撤销、重做和预览按钮
        return [
          IconButton(
            onPressed: _undoHistory.isEmpty ? null : _undo,
            icon: const Icon(Icons.undo),
            tooltip: '撤销',
          ),
          IconButton(
            onPressed: _redoHistory.isEmpty ? null : _redo,
            icon: const Icon(Icons.redo),
            tooltip: '重做',
          ),
          IconButton(
            onPressed: () {
              // 切换到预览模式前保存当前文本状态
              _lastText = _textController.text;
              // 确保Bloc状态保留编辑内容
              context.read<NoteDetailBloc>().add(NoteDetailUpdateContent(_textController.text));
              // 切换到预览模式
              context.read<NoteDetailBloc>().add(const NoteDetailToggleEditMode());
            },
            icon: const Icon(Icons.remove_red_eye_outlined),
            tooltip: '预览Markdown',
          ),
        ];
      }
    } else {
      // 正常查看模式 - 不显示编辑按钮，因为点击内容可以进入编辑模式
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NoteDetailBloc, NoteDetailState>(
      listener: (context, state) {
        if (state is NoteDetailOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        } else if (state is NoteDetailLoadFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        } else if (state is NoteDetailLoaded) {
          // 当状态变为已加载，且编辑模式发生变化时，更新控制器
          if (state.editMode == NoteEditMode.reading && _textController.text != state.note.content) {
            _textController.text = state.note.content;
            _titleController.text = NoteUtils.getTitle(state.note.content);
            _lastText = state.note.content;
          }
        }
      },
      builder: (context, state) {
        if (state is NoteDetailLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (state is NoteDetailLoaded) {
          final note = state.note;
          final theme = Theme.of(context);
          final isEditing = state.editMode == NoteEditMode.editing;
          final isPreviewMode = state.editMode == NoteEditMode.previewing;

          // 添加WillPopScope处理退出时自动保存
          return WillPopScope(
            onWillPop: () async {
              // 检查是否有未保存的更改
              if (state.hasUnsavedChanges || _textController.text != state.note.content) {
                // 自动保存笔记
                await _saveNote();
              }
              return true;
            },
            child: Scaffold(
            resizeToAvoidBottomInset: false,
            appBar: AppBar(
              centerTitle: false,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '修改于 ${note.updatedAt.month}月${note.updatedAt.day}日, ${note.updatedAt.toYYMMDD()}',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                  if (note.locationInfo != null && note.locationInfo!.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on, size: 12, color: Colors.grey.shade600),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            note.locationInfo!,
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              actions: _buildAppBarActions(state),
            ),
            body: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 使用重构后的组件显示内容
                            if (isEditing || isPreviewMode) 
                              !isPreviewMode
                                ? NoteEditorWidget(
                                    titleController: _titleController,
                                    textController: _textController,
                                    focusNode: _focusNode,
                                    noteId: note.id,
                                    onTitleChanged: _updateContentFromTitle,
                                    onDeleteImage: _handleDeleteImage,
                                    onTagRemoved: _handleTagRemoved,
                                  )
                                : NotePreviewWidget(
                                    content: _textController.text,
                                    title: _titleController.text,
                                    noteId: note.id,
                                    onDeleteImage: _handleDeleteImage,
                                    onTagRemoved: _handleTagRemoved,
                                  )
                            else
                              NoteReadingWidget(
                                note: note,
                                onTap: _switchToEditMode,
                                getTitleFn: NoteUtils.getTitle,
                                getContentBodyFn: NoteUtils.getContentBody,
                              ),
                            
                            const SizedBox(height: 16),
                            
                            // 使用重构后的图片网格组件
                            NoteImageGrid(
                              noteId: note.id,
                              isEditing: isEditing,
                              newImagePaths: _newImagePaths,
                              deletedImagePaths: _deletedImagePaths,
                              onDeleteImage: isEditing ? _handleDeleteImage : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // 使用重构后的编辑操作栏组件
                  if (isEditing && !isPreviewMode)
                    NoteEditActionsBar(
                      onInsertText: _insertTextAtCursor,
                      onPickImage: _pickImageFromGallery,
                      onTakePhoto: () {}, // 暂不实现拍照功能
                      onSave: _saveNote,
                    ),
                ],
              ),
            ),
          ),
          );
        }
        
        // 默认显示加载中
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  // 撤销操作
  void _undo() {
    if (_undoHistory.isEmpty) return;
    
    // 保存当前状态到重做历史
    _redoHistory.add(_textController.text);
    
    // 恢复上一个状态
    final previousText = _undoHistory.removeLast();
    _isUndoRedo = true; // 标记这是一个撤销操作
    
    setState(() {
      // 恢复文本并设置光标位置
      _textController.value = TextEditingValue(
        text: previousText,
        selection: TextSelection.collapsed(offset: previousText.length),
      );
      _lastText = previousText; // 更新最后文本
      // 同步更新标题
      _titleController.text = NoteUtils.getTitle(previousText);
    });
    
    // 通知BLoC内容已更新
    context.read<NoteDetailBloc>().add(NoteDetailUpdateContent(previousText));
  }
  
  // 重做操作
  void _redo() {
    if (_redoHistory.isEmpty) return;
    
    // 保存当前状态到撤销历史
    _undoHistory.add(_textController.text);
    
    // 恢复下一个状态
    final nextText = _redoHistory.removeLast();
    _isUndoRedo = true; // 标记这是一个重做操作
    
    setState(() {
      // 恢复文本并设置光标位置
      _textController.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextText.length),
      );
      _lastText = nextText; // 更新最后文本
      // 同步更新标题
      _titleController.text = NoteUtils.getTitle(nextText);
    });
    
    // 通知BLoC内容已更新
    context.read<NoteDetailBloc>().add(NoteDetailUpdateContent(nextText));
  }
}