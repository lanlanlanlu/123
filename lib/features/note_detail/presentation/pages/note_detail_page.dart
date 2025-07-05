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
import 'package:share_plus/share_plus.dart';

// 导入重构后的组件
import 'package:record/features/note_detail/presentation/widgets/note_editor_widget.dart';
import 'package:record/features/note_detail/presentation/widgets/note_preview_widget.dart';
import 'package:record/features/note_detail/presentation/widgets/note_reading_widget.dart';
import 'package:record/features/note_detail/presentation/widgets/note_image_grid.dart';
import 'package:record/features/note_detail/presentation/widgets/note_edit_actions_bar.dart';
import 'package:record/features/note_detail/presentation/widgets/note_utils.dart';
// 导入Quill编辑器组件
import 'package:record/features/note_detail/presentation/widgets/quill_editor_widget.dart';
import 'package:record/features/note_detail/presentation/widgets/quill_preview_widget.dart';

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
  
  // 修改GlobalKey类型为通用State类型
  final GlobalKey<State<QuillEditorWidget>> _quillEditorKey = GlobalKey<State<QuillEditorWidget>>();

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
  void _handleTagRemoved(String tagName) {
    final currentState = context.read<NoteDetailBloc>().state;
    if (currentState is NoteDetailLoaded) {
      // 查找与该名称匹配的标签
      final tag = currentState.tags.firstWhere(
        (t) => t.name == tagName,
        orElse: () => Tag(id: -1, name: ''),
      );
      
      if (tag.id != -1) {
        context.read<NoteDetailBloc>().add(NoteDetailRemoveTag(tag.id));
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
      listenWhen: (previous, current) {
        // 只有当状态从NoteDetailLoaded变为其他状态或操作成功时才响应
        return (previous is NoteDetailLoaded && !(current is NoteDetailLoaded)) ||
          current is NoteDetailOperationSuccess;
      },
      listener: (context, state) {
        if (state is NoteDetailOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        } else if (state is NoteDetailLoadFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      builder: (context, state) {
        if (state is NoteDetailLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (state is NoteDetailLoaded) {
          return WillPopScope(
            // 拦截返回事件，检查是否有未保存的更改
            onWillPop: () async {
              if (state.hasUnsavedChanges) {
                // 如果有未保存的更改，提示用户是否保存
                final shouldSave = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('有未保存的更改'),
                    content: const Text('是否保存更改？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('不保存'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('保存'),
                      ),
                    ],
                  ),
                );
                
                if (shouldSave == true) {
                  await _saveNote();
                }
              }
              return true;
            },
            child: Scaffold(
              key: _scaffoldKey,
              appBar: AppBar(
                title: Text(state.note.title.isEmpty ? '新建笔记' : state.note.title),
                actions: [
                  // 根据不同状态显示相应按钮
                  // 编辑模式：显示保存按钮
                  if (state.editMode == NoteEditMode.editing)
                    IconButton(
                      icon: const Icon(Icons.save),
                      onPressed: _saveNote,
                      tooltip: '保存笔记',
                    )
                  // 阅读模式：显示编辑按钮
                  else if (state.editMode == NoteEditMode.reading)
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: _switchToEditMode,
                      tooltip: '编辑笔记',
                    )
                  // 预览模式：显示返回编辑按钮
                  else if (state.editMode == NoteEditMode.previewing)
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => context.read<NoteDetailBloc>().add(const NoteDetailToggleEditMode()),
                      tooltip: '返回编辑',
                    ),
                  
                  // 编辑模式下额外显示预览按钮
                  if (state.editMode == NoteEditMode.editing)
                    IconButton(
                      icon: const Icon(Icons.preview),
                      onPressed: () => context.read<NoteDetailBloc>().add(const NoteDetailToggleEditMode()),
                      tooltip: '预览内容',
                    ),
                  
                  // 菜单选项
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        _showDeleteConfirmation(context);
                      } else if (value == 'share') {
                        _shareNoteContent(context, state.displayContent);
                      } else if (value == 'thumbnail') {
                        context.read<NoteDetailBloc>().add(const NoteDetailToggleThumbnailMode());
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'thumbnail',
                        child: Row(
                          children: [
                            Icon(
                              state.thumbnailMode ? Icons.image : Icons.image_outlined,
                              color: Theme.of(context).iconTheme.color,
                            ),
                            const SizedBox(width: 8),
                            Text(state.thumbnailMode ? '显示图片' : '隐藏图片'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share),
                            SizedBox(width: 8),
                            Text('分享笔记'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('删除', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              body: Column(
                children: [
                  // 主内容区域
                  Expanded(
                    child: SafeArea(
                      // 不为底部添加安全区域，工具栏会自己处理
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0),
                        child: _buildContent(state),
                      ),
                    ),
                  ),
                  
                  // 当处于编辑模式时显示底部工具栏，直接放在Column底部
                  if (state.editMode == NoteEditMode.editing)
                    NoteEditActionsBar(
                      onInsertText: _insertTextAtCursor,
                      onPickImage: _pickImageFromGallery,
                      onTakePhoto: () {}, // 暂不实现拍照功能
                      onSave: _saveNote,
                      onFormatText: (prefix, suffix) {
                        _insertFormattedTextAtCursor(prefix, suffix);
                      },
                      onInsertList: (marker) {
                        _insertTextAtCursor('$marker ');
                      },
                    ),
                ],
              ),
              
              // 移除底部字数统计，所有模式下都不显示底部导航栏
              bottomNavigationBar: const SizedBox.shrink(),
            ),
          );
        } else {
          // 处理错误状态
          return Scaffold(
            appBar: AppBar(title: const Text('笔记详情')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    state is NoteDetailLoadFailure
                        ? state.message
                        : '未知错误',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // 重新加载笔记
                      context.read<NoteDetailBloc>().add(NoteDetailLoadNote(widget.initialNote.id));
                    },
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  // 构建主内容区域
  Widget _buildContent(NoteDetailLoaded state) {
    switch (state.editMode) {
      case NoteEditMode.reading:
        return NoteReadingWidget(
          note: state.note,
          onTap: _switchToEditMode,
          getTitleFn: (content) => state.note.title,
          getContentBodyFn: (content) => state.note.content,
          thumbnailMode: state.thumbnailMode,
        );
      case NoteEditMode.editing:
        // 使用QuillEditorWidget替代NoteEditorWidget
        return QuillEditorWidget(
          key: _quillEditorKey,
          noteId: state.note.id,
          titleController: _titleController,
          content: _textController.text,
          focusNode: _focusNode,
          onTitleChanged: _updateContentFromTitle,
          onContentChanged: (content) {
            context.read<NoteDetailBloc>().add(NoteDetailUpdateContent(content));
          },
          onDeleteImage: _handleDeleteImage,
          onTagRemoved: _handleTagRemoved,
          thumbnailMode: state.thumbnailMode,
        );
      case NoteEditMode.previewing:
        return QuillPreviewWidget(
          noteId: state.note.id,
          title: state.displayTitle,
          content: state.displayContent,
          onDeleteImage: null,
          onTagRemoved: null,
          thumbnailMode: state.thumbnailMode,
        );
    }
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

  // 在光标位置插入带格式的文本
  void _insertFormattedTextAtCursor(String prefix, String suffix) {
    final selection = _textController.selection;
    final text = _textController.text;
    
    if (selection.isCollapsed) {
      // 光标位置，没有选中文本
      final newText = text.substring(0, selection.baseOffset) + 
                    prefix + suffix + 
                    text.substring(selection.baseOffset);
      
      _textController.value = TextEditingValue(
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
      
      _textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.baseOffset + prefix.length + selectedText.length + suffix.length
        ),
      );
    }
  }

  // 添加缺失的分享方法
  void _shareNoteContent(BuildContext context, String content) {
    Share.share(content);
  }

  // 添加确认删除方法
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除笔记'),
        content: const Text('确定要删除此笔记吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<NoteDetailBloc>().add(const NoteDetailDeleteNote());
              context.pop();
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}