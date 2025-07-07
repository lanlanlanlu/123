import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:record_app/data/database/database.dart';
import 'package:record_app/data/repository/index.dart';

// Events
abstract class TagListEvent extends Equatable {
  const TagListEvent();

  @override
  List<Object?> get props => [];
}

class TagListLoadTags extends TagListEvent {
  const TagListLoadTags();
}

class TagDeleted extends TagListEvent {
  final String tagName;

  const TagDeleted(this.tagName);

  @override
  List<Object?> get props => [tagName];
}

// States
abstract class TagListState extends Equatable {
  const TagListState();

  @override
  List<Object?> get props => [];
}

class TagListInitial extends TagListState {
  const TagListInitial();
}

class TagListLoading extends TagListState {
  const TagListLoading();
}

class TagListLoaded extends TagListState {
  final List<Tag> tags;
  final Set<String> tagYears;
  final bool isAfterDeletion;

  const TagListLoaded(
    this.tags, {
    this.tagYears = const {},
    this.isAfterDeletion = false,
  });

  @override
  List<Object?> get props => [tags, tagYears, isAfterDeletion];
  
  TagListLoaded copyWith({
    List<Tag>? tags,
    Set<String>? tagYears,
    bool? isAfterDeletion,
  }) {
    return TagListLoaded(
      tags ?? this.tags,
      tagYears: tagYears ?? this.tagYears,
      isAfterDeletion: isAfterDeletion ?? this.isAfterDeletion,
    );
  }
}

class TagListError extends TagListState {
  final String message;

  const TagListError(this.message);

  @override
  List<Object?> get props => [message];
}

class TagOperationSuccess extends TagListState {
  final String message;

  const TagOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class TagListBloc extends Bloc<TagListEvent, TagListState> {
  final TagsRepository _tagsRepository;
  StreamSubscription? _tagsSubscription;

  TagListBloc({required TagsRepository tagsRepository})
      : _tagsRepository = tagsRepository,
        super(const TagListInitial()) {
    on<TagListLoadTags>(_onLoadTags);
    on<TagDeleted>(_onTagDeleted);
    on<_TagListTagsUpdated>(_onTagsUpdated);
    on<_TagListError>(_onError);
  }

  Future<void> _onLoadTags(TagListLoadTags event, Emitter<TagListState> emit) async {
    emit(const TagListLoading());

    await _tagsSubscription?.cancel();

    try {
      // 获取年份信息
      Set<String> years = {};
      try {
        years = await _tagsRepository.getTagYears();
      } catch (e) {
        // 如果获取年份失败，使用空集合，但不中断整个流程
        print('获取标签年份失败: $e');
      }
      
      // 订阅标签流
    _tagsSubscription = _tagsRepository.watchAllTags().listen(
        (tags) => add(_TagListTagsUpdated(tags, years)),
        onError: (error) => add(_TagListError('获取标签失败: $error')),
      );
    } catch (e) {
      emit(TagListError('加载标签失败: $e'));
    }
  }

  Future<void> _onTagDeleted(TagDeleted event, Emitter<TagListState> emit) async {
    try {
      await _tagsRepository.deleteTag(event.tagName);
      
      // 如果当前状态是已加载状态，我们可以更新标志位
      if (state is TagListLoaded) {
        final currentState = state as TagListLoaded;
        emit(currentState.copyWith(isAfterDeletion: true));
      }
      
      // 也可以发送一个操作成功的状态
      emit(const TagOperationSuccess('标签已删除'));
      
      // 重新加载标签列表
      add(const TagListLoadTags());
    } catch (e) {
      emit(TagListError('删除标签失败: $e'));
    }
  }

  Future<void> _onTagsUpdated(_TagListTagsUpdated event, Emitter<TagListState> emit) async {
    // 如果当前状态是已加载状态，并且有isAfterDeletion标志，保留该标志
    final bool isAfterDeletion = state is TagListLoaded ? 
        (state as TagListLoaded).isAfterDeletion : false;
    
    emit(TagListLoaded(
      event.tags, 
      tagYears: event.years,
      isAfterDeletion: isAfterDeletion,
    ));
  }

  Future<void> _onError(_TagListError event, Emitter<TagListState> emit) async {
    emit(TagListError(event.message));
  }

  @override
  Future<void> close() {
    _tagsSubscription?.cancel();
    return super.close();
  }
}

// Internal Events
class _TagListTagsUpdated extends TagListEvent {
  final List<Tag> tags;
  final Set<String> years;

  const _TagListTagsUpdated(this.tags, this.years);

  @override
  List<Object?> get props => [tags, years];
}

class _TagListError extends TagListEvent {
  final String message;

  const _TagListError(this.message);

  @override
  List<Object?> get props => [message];
} 