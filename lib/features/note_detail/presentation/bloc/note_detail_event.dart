import 'package:equatable/equatable.dart';
import 'package:record_app/data/database/database.dart';

/// NoteDetail页面的所有事件基类
abstract class NoteDetailEvent extends Equatable {
  const NoteDetailEvent();

  @override
  List<Object?> get props => [];
}

/// 加载笔记详情事件
class NoteDetailLoadNote extends NoteDetailEvent {
  final int noteId;

  const NoteDetailLoadNote(this.noteId);

  @override
  List<Object?> get props => [noteId];
}

/// 更新笔记内容事件
class NoteDetailUpdateContent extends NoteDetailEvent {
  final String content;

  const NoteDetailUpdateContent(this.content);

  @override
  List<Object?> get props => [content];
}

/// 更新笔记标题事件
class NoteDetailUpdateTitle extends NoteDetailEvent {
  final String title;

  const NoteDetailUpdateTitle(this.title);

  @override
  List<Object?> get props => [title];
}

/// 保存笔记事件
class NoteDetailSaveNote extends NoteDetailEvent {
  const NoteDetailSaveNote();
}

/// 删除笔记事件
class NoteDetailDeleteNote extends NoteDetailEvent {
  const NoteDetailDeleteNote();
}

/// 添加标签事件
class NoteDetailAddTag extends NoteDetailEvent {
  final String tagName;

  const NoteDetailAddTag(this.tagName);

  @override
  List<Object?> get props => [tagName];
}

/// 删除标签事件
class NoteDetailRemoveTag extends NoteDetailEvent {
  final int tagId;

  const NoteDetailRemoveTag(this.tagId);

  @override
  List<Object?> get props => [tagId];
}

/// 更新笔记图片事件
class NoteDetailUpdateImages extends NoteDetailEvent {
  final List<String> newImagePaths;
  final List<String> deletedImagePaths;

  const NoteDetailUpdateImages({
    required this.newImagePaths,
    required this.deletedImagePaths,
  });

  @override
  List<Object?> get props => [newImagePaths, deletedImagePaths];
}

/// 切换小图模式事件
class NoteDetailToggleThumbnailMode extends NoteDetailEvent {
  const NoteDetailToggleThumbnailMode();
}

/// 检查并处理远程更新事件
class NoteDetailCheckRemoteUpdate extends NoteDetailEvent {
  const NoteDetailCheckRemoteUpdate();

  @override
  List<Object?> get props => [];
}

/// 应用远程更新事件
class NoteDetailApplyRemoteUpdate extends NoteDetailEvent {
  const NoteDetailApplyRemoteUpdate();

  @override
  List<Object?> get props => [];
} 