import 'package:equatable/equatable.dart';
import 'package:record/data/database/database.dart';

/// 笔记编辑模式
enum NoteEditMode {
  /// 阅读模式
  reading,
  /// 编辑模式
  editing,
  /// 预览模式
  previewing
}

/// NoteDetail页面的所有状态基类
abstract class NoteDetailState extends Equatable {
  const NoteDetailState();

  @override
  List<Object?> get props => [];
}

/// 初始状态
class NoteDetailInitial extends NoteDetailState {
  const NoteDetailInitial();
}

/// 加载中状态
class NoteDetailLoading extends NoteDetailState {
  const NoteDetailLoading();
}

/// 加载成功状态
class NoteDetailLoaded extends NoteDetailState {
  final Note note;
  final NoteEditMode editMode;
  final List<Tag> tags;
  final String? draftContent;
  final String? draftTitle;
  final bool hasImageChanges; // 是否有图片变更
  final int imageChangeCount; // 图片变更计数
  
  const NoteDetailLoaded({
    required this.note,
    this.editMode = NoteEditMode.reading,
    required this.tags,
    this.draftContent,
    this.draftTitle,
    this.hasImageChanges = false,
    this.imageChangeCount = 0,
  });
  
  /// 当前展示的标题（草稿或原始标题）
  String get displayTitle => draftTitle ?? note.title;
  
  /// 当前展示的内容（草稿或原始内容）
  String get displayContent => draftContent ?? note.content;
  
  /// 创建一个副本，但更新某些字段
  NoteDetailLoaded copyWith({
    Note? note,
    NoteEditMode? editMode,
    List<Tag>? tags,
    String? draftContent,
    String? draftTitle,
    bool? hasUnsavedChanges,
    bool? hasImageChanges,
    int? imageChangeCount,
    bool clearDraft = false,
  }) {
    return NoteDetailLoaded(
      note: note ?? this.note,
      editMode: editMode ?? this.editMode,
      tags: tags ?? this.tags,
      draftContent: clearDraft ? null : (draftContent ?? this.draftContent),
      draftTitle: clearDraft ? null : (draftTitle ?? this.draftTitle),
      hasImageChanges: clearDraft ? false : (hasImageChanges ?? this.hasImageChanges),
      imageChangeCount: clearDraft ? 0 : (imageChangeCount ?? this.imageChangeCount),
    );
  }
  
  /// 判断是否有未保存的更改
  bool get hasUnsavedChanges => draftContent != null || draftTitle != null || hasImageChanges;
  
  @override
  List<Object?> get props => [note, editMode, tags, draftContent, draftTitle, hasImageChanges, imageChangeCount];
}

/// 加载失败状态
class NoteDetailLoadFailure extends NoteDetailState {
  final String message;
  
  const NoteDetailLoadFailure(this.message);
  
  @override
  List<Object?> get props => [message];
}

/// 操作成功状态
class NoteDetailOperationSuccess extends NoteDetailState {
  final String message;
  
  const NoteDetailOperationSuccess(this.message);
  
  @override
  List<Object?> get props => [message];
} 