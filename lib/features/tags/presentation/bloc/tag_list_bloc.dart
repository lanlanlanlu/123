import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:record/data/database/database.dart';
import 'package:record/data/repository/index.dart';

// Events
abstract class TagListEvent extends Equatable {
  const TagListEvent();

  @override
  List<Object?> get props => [];
}

class TagListLoadTags extends TagListEvent {
  const TagListLoadTags();
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

  const TagListLoaded(this.tags);

  @override
  List<Object?> get props => [tags];
}

class TagListError extends TagListState {
  final String message;

  const TagListError(this.message);

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
    on<_TagListTagsUpdated>(_onTagsUpdated);
    on<_TagListError>(_onError);
  }

  Future<void> _onLoadTags(TagListLoadTags event, Emitter<TagListState> emit) async {
    emit(const TagListLoading());

    await _tagsSubscription?.cancel();

    _tagsSubscription = _tagsRepository.watchAllTags().listen(
      (tags) => add(_TagListTagsUpdated(tags)),
      onError: (error) => add(_TagListError(error.toString())),
    );
  }

  Future<void> _onTagsUpdated(_TagListTagsUpdated event, Emitter<TagListState> emit) async {
    emit(TagListLoaded(event.tags));
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

  const _TagListTagsUpdated(this.tags);

  @override
  List<Object?> get props => [tags];
}

class _TagListError extends TagListEvent {
  final String message;

  const _TagListError(this.message);

  @override
  List<Object?> get props => [message];
} 