import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:record_app/data/database/database.dart';
import 'package:record_app/data/repository/index.dart';
import 'package:record_app/features/note_detail/presentation/bloc/note_detail_event.dart';
import 'package:record_app/features/note_detail/presentation/bloc/note_detail_state.dart';

class NoteDetailBloc extends Bloc<NoteDetailEvent, NoteDetailState> {
  final NotesRepository _notesRepository;
  final TagsRepository _tagsRepository;
  
  // 保存笔记和标签流订阅，以便在BLoC销毁时取消订阅
  StreamSubscription? _noteSubscription;
  StreamSubscription? _tagsSubscription;
  
  // 当前笔记ID
  int? _currentNoteId;

  NoteDetailBloc({
    required NotesRepository notesRepository,
    required TagsRepository tagsRepository,
  }) : _notesRepository = notesRepository,
       _tagsRepository = tagsRepository,
       super(const NoteDetailInitial()) {
    on<NoteDetailLoadNote>(_onLoadNote);
    on<NoteDetailUpdateContent>(_onUpdateContent);
    on<NoteDetailUpdateTitle>(_onUpdateTitle);
    on<NoteDetailSaveNote>(_onSaveNote);
    on<NoteDetailDeleteNote>(_onDeleteNote);
    on<NoteDetailAddTag>(_onAddTag);
    on<NoteDetailRemoveTag>(_onRemoveTag);
    on<NoteDetailUpdateImages>(_onUpdateImages);
    on<NoteDetailToggleThumbnailMode>(_onToggleThumbnailMode);
    
    // 内部事件处理
    on<_NoteDetailUpdated>(_onNoteUpdated);
    on<_NoteDetailTagsUpdated>(_onTagsUpdated);
    on<_NoteDetailError>(_onError);
  }

  /// 处理加载笔记事件
  Future<void> _onLoadNote(NoteDetailLoadNote event, Emitter<NoteDetailState> emit) async {
    emit(const NoteDetailLoading());
    
    try {
      _currentNoteId = event.noteId;
      
      // 取消之前的订阅（如果有）
      await _noteSubscription?.cancel();
      await _tagsSubscription?.cancel();
      
      // 订阅笔记流
      _noteSubscription = _notesRepository.watchNote(event.noteId).listen(
        (note) => add(_NoteDetailUpdated(note)),
        onError: (error) => add(_NoteDetailError(error.toString())),
      );
      
      // 订阅标签流
      _tagsSubscription = _tagsRepository.watchTagsForNote(event.noteId).listen(
        (tags) => add(_NoteDetailTagsUpdated(tags)),
        onError: (error) => add(_NoteDetailError(error.toString())),
      );
    } catch (e) {
      emit(NoteDetailLoadFailure(e.toString()));
    }
  }

  /// 处理内部笔记更新事件
  Future<void> _onNoteUpdated(_NoteDetailUpdated event, Emitter<NoteDetailState> emit) async {
    final currentState = state;
    
    if (currentState is NoteDetailLoaded) {
      emit(currentState.copyWith(note: event.note));
    } else if (currentState is NoteDetailLoading || currentState is NoteDetailInitial) {
      // 首次加载，需要等待标签数据
      final tags = await _tagsRepository.getTagsForNote(_currentNoteId!);
      emit(NoteDetailLoaded(
        note: event.note,
        tags: tags,
        editMode: NoteEditMode.editing, // 直接进入编辑模式
      ));
    }
  }
  
  /// 处理内部标签更新事件
  Future<void> _onTagsUpdated(_NoteDetailTagsUpdated event, Emitter<NoteDetailState> emit) async {
    final currentState = state;
    
    if (currentState is NoteDetailLoaded) {
      emit(currentState.copyWith(tags: event.tags));
    }
  }

  /// 处理更新笔记内容事件
  Future<void> _onUpdateContent(NoteDetailUpdateContent event, Emitter<NoteDetailState> emit) async {
    final currentState = state;
    
    if (currentState is NoteDetailLoaded) {
      emit(currentState.copyWith(draftContent: event.content));
    }
  }

  /// 处理更新笔记标题事件
  Future<void> _onUpdateTitle(NoteDetailUpdateTitle event, Emitter<NoteDetailState> emit) async {
    final currentState = state;
    
    if (currentState is NoteDetailLoaded) {
      emit(currentState.copyWith(draftTitle: event.title));
    }
  }

  /// 处理保存笔记事件
  Future<void> _onSaveNote(NoteDetailSaveNote event, Emitter<NoteDetailState> emit) async {
    final currentState = state;
    
    // 无论是否有未保存的更改，我们都需要确保标签关系正确
    if (currentState is NoteDetailLoaded) {
      try {
        final rawText = currentState.draftContent ?? currentState.note.content;
        
        // 解析标签和位置
        final tagRegExp = RegExp(r"#([\p{L}\p{N}_]+)", unicode: true);
        final locationRegExp = RegExp(r"@([\p{L}\p{N}_]+)", unicode: true);
        
        // 提取文本中所有的标签，包括现有标签
        final tagNames = tagRegExp.allMatches(rawText).map((match) => match.group(1)!).toSet();
        final locations = locationRegExp.allMatches(rawText).map((match) => match.group(1)!).toList();
        
        // 提取位置信息
        String? locationToSave;
        if (locations.isNotEmpty) {
          locationToSave = locations.last;
        } else {
          locationToSave = currentState.note.locationInfo;
        }
        
        // 清理内容，移除标签和位置标记
        String contentToSave = rawText.replaceAll(tagRegExp, '').replaceAll(locationRegExp, '').trim();
        
        // 使用用户输入的标题，而不是从内容中提取
        final title = currentState.draftTitle ?? currentState.note.title;
        
        // 创建NotesCompanion对象进行更新
        final updatedNoteCompanion = NotesCompanion(
          id: Value(currentState.note.id),
          title: Value(title),
          content: Value(contentToSave), // 内容不再包含标题
          locationInfo: Value(locationToSave),
          updatedAt: Value(DateTime.now()),
        );
        
        await _notesRepository.updateNote(updatedNoteCompanion);
        
        // 处理位置
        if (locationToSave != null && locationToSave.isNotEmpty) {
          await _notesRepository.addLocationToNote(currentState.note.id, locationToSave, DateTime.now());
        }
        
        // 处理标签
        // 获取当前文本中的标签和已存在的标签
        final currentTags = await _tagsRepository.getTagsForNote(currentState.note.id);
        final currentTagNames = currentTags.map((t) => t.name).toSet();
        
        // 始终将新标签和现有标签合并，而不是替换
        final bool contentUnchanged = currentState.draftContent == null || currentState.draftContent == currentState.note.content;
        // 合并文本中的标签和现有标签，确保不会丢失任何标签
        final Set<String> finalTagNames = contentUnchanged ? currentTagNames : {...currentTagNames, ...tagNames};
        
        // 删除不再存在的标签
        for (final tag in currentTags) {
          if (!finalTagNames.contains(tag.name)) {
            await _tagsRepository.removeTagFromNote(currentState.note.id, tag.id);
          }
        }
        
        // 添加新标签
        for (final tagName in finalTagNames) {
          if (!currentTagNames.contains(tagName)) {
            await _notesRepository.addTagToNote(currentState.note.id, tagName);
          }
        }
        
        // 注意：_onSaveNote方法不处理图片更新，因为这是在UI层通过NoteDetailUpdateImages事件处理的
        
        // 获取更新后的笔记以确保UI能立即显示更新后的地址信息
        final updatedNote = await _notesRepository.getNoteById(currentState.note.id);
        
        // 清除草稿并切换到阅读模式，同时更新笔记对象
        emit(currentState.copyWith(
          clearDraft: true,
          editMode: NoteEditMode.editing,
          note: updatedNote,
          hasImageChanges: false,
          imageChangeCount: 0,
        ));
        
        // 恢复更新后的状态
        emit(currentState.copyWith(
          clearDraft: true,
          editMode: NoteEditMode.editing,
          note: updatedNote,
          hasImageChanges: false,
          imageChangeCount: 0,
        ));
      } catch (e) {
        emit(NoteDetailLoadFailure('保存笔记失败: ${e.toString()}'));
        
        // 恢复之前的状态
        if (currentState is NoteDetailLoaded) {
          emit(currentState);
        }
      }
    }
  }

  /// 处理删除笔记事件
  Future<void> _onDeleteNote(NoteDetailDeleteNote event, Emitter<NoteDetailState> emit) async {
    final currentState = state;
    
    if (currentState is NoteDetailLoaded && _currentNoteId != null) {
      try {
        await _notesRepository.softDeleteNote(_currentNoteId!);
        emit(const NoteDetailOperationSuccess('笔记已删除'));
      } catch (e) {
        emit(NoteDetailLoadFailure('删除笔记失败: ${e.toString()}'));
        
        // 恢复之前的状态
        if (currentState is NoteDetailLoaded) {
          emit(currentState);
        }
      }
    }
  }

  /// 处理添加标签事件
  Future<void> _onAddTag(NoteDetailAddTag event, Emitter<NoteDetailState> emit) async {
    if (_currentNoteId == null) return;
    
    try {
      await _tagsRepository.addTagToNote(_currentNoteId!, event.tagName);
    } catch (e) {
      final currentState = state;
      emit(NoteDetailLoadFailure('添加标签失败: ${e.toString()}'));
      
      // 恢复之前的状态
      if (currentState is NoteDetailLoaded) {
        emit(currentState);
      }
    }
  }

  /// 处理删除标签事件
  Future<void> _onRemoveTag(NoteDetailRemoveTag event, Emitter<NoteDetailState> emit) async {
    if (_currentNoteId == null) return;
    
    try {
      await _tagsRepository.removeTagFromNote(_currentNoteId!, event.tagId);
    } catch (e) {
      final currentState = state;
      emit(NoteDetailLoadFailure('删除标签失败: ${e.toString()}'));
      
      // 恢复之前的状态
      if (currentState is NoteDetailLoaded) {
        emit(currentState);
      }
    }
  }
  
  /// 处理错误事件
  Future<void> _onError(_NoteDetailError event, Emitter<NoteDetailState> emit) async {
    emit(NoteDetailLoadFailure(event.message));
  }

  /// 处理切换小图模式事件
  Future<void> _onToggleThumbnailMode(NoteDetailToggleThumbnailMode event, Emitter<NoteDetailState> emit) async {
    final currentState = state;
    
    if (currentState is NoteDetailLoaded) {
      // 反转当前的小图模式状态
      emit(currentState.copyWith(
        thumbnailMode: !currentState.thumbnailMode,
      ));
    }
  }

  /// 处理更新图片事件
  Future<void> _onUpdateImages(NoteDetailUpdateImages event, Emitter<NoteDetailState> emit) async {
    if (_currentNoteId == null) {
      emit(const NoteDetailLoadFailure('找不到当前笔记ID，无法更新图片'));
      return;
    }
    
    try {
      // 1. 获取当前笔记的所有图片
      final currentImages = await _notesRepository.getImagesForNote(_currentNoteId!);
      final currentImagePaths = currentImages.map((img) => img.path).toList();
      
      // 2. 计算最终图片列表，使用Set确保唯一性
      final Set<String> finalImagePathsSet = <String>{};
      
      // 首先添加当前图片中未被删除的
      for (final path in currentImagePaths) {
        if (!event.deletedImagePaths.contains(path)) {
          finalImagePathsSet.add(path);
        }
      }
      
      // 添加新图片，Set自动处理重复项
      finalImagePathsSet.addAll(event.newImagePaths);
      
      // 转换为列表
      final finalImagePaths = finalImagePathsSet.toList();
      
      // 3. 检查是否有图片变更
      bool hasImageChanges = event.newImagePaths.isNotEmpty || event.deletedImagePaths.isNotEmpty;
      
      // 4. 更新笔记的图片
      await _notesRepository.updateImagesForNote(_currentNoteId!, finalImagePaths);
      
      // 5. 获取更新后的笔记并更新UI
      final updatedNote = await _notesRepository.getNoteById(_currentNoteId!);
      final currentState = state;
      
      if (currentState is NoteDetailLoaded) {
        // 更新状态，包括图片变更标记
        emit(currentState.copyWith(
          note: updatedNote,
          hasImageChanges: hasImageChanges,
          imageChangeCount: currentState.imageChangeCount + 
              (event.newImagePaths.length + event.deletedImagePaths.length),
        ));
      }
    } catch (e) {
      final currentState = state;
      emit(NoteDetailLoadFailure('更新图片失败: ${e.toString()}'));
      
      // 恢复之前的状态
      if (currentState is NoteDetailLoaded) {
        emit(currentState);
      }
    }
  }

  @override
  Future<void> close() {
    _noteSubscription?.cancel();
    _tagsSubscription?.cancel();
    return super.close();
  }
}

/// 内部事件: 笔记数据已更新
class _NoteDetailUpdated extends NoteDetailEvent {
  final Note note;

  const _NoteDetailUpdated(this.note);

  @override
  List<Object?> get props => [note];
}

/// 内部事件: 标签数据已更新
class _NoteDetailTagsUpdated extends NoteDetailEvent {
  final List<Tag> tags;

  const _NoteDetailTagsUpdated(this.tags);

  @override
  List<Object?> get props => [tags];
}

/// 内部事件: 发生错误
class _NoteDetailError extends NoteDetailEvent {
  final String message;

  const _NoteDetailError(this.message);

  @override
  List<Object?> get props => [message];
} 