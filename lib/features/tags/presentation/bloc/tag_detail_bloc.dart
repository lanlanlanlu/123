import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:record/data/database/database.dart';
import 'package:record/data/repository/index.dart';

// Events
abstract class TagDetailEvent extends Equatable {
  const TagDetailEvent();

  @override
  List<Object?> get props => [];
}

class TagDetailLoadNotes extends TagDetailEvent {
  final String tagName;

  const TagDetailLoadNotes(this.tagName);

  @override
  List<Object?> get props => [tagName];
}

// States
abstract class TagDetailState extends Equatable {
  const TagDetailState();

  @override
  List<Object?> get props => [];
}

class TagDetailInitial extends TagDetailState {
  const TagDetailInitial();
}

class TagDetailLoading extends TagDetailState {
  const TagDetailLoading();
}

class TagDetailLoaded extends TagDetailState {
  final List<Note> notes;
  final String tagName;

  const TagDetailLoaded({required this.notes, required this.tagName});

  @override
  List<Object?> get props => [notes, tagName];
}

class TagDetailError extends TagDetailState {
  final String message;

  const TagDetailError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class TagDetailBloc extends Bloc<TagDetailEvent, TagDetailState> {
  final NotesRepository _notesRepository;
  StreamSubscription? _notesSubscription;

  TagDetailBloc({required NotesRepository notesRepository})
      : _notesRepository = notesRepository,
        super(const TagDetailInitial()) {
    on<TagDetailLoadNotes>(_onLoadNotes);
    on<_TagDetailNotesUpdated>(_onNotesUpdated);
    on<_TagDetailError>(_onError);
  }

  Future<void> _onLoadNotes(TagDetailLoadNotes event, Emitter<TagDetailState> emit) async {
    emit(const TagDetailLoading());

    await _notesSubscription?.cancel();

    _notesSubscription = _notesRepository.watchNotesByTagName(event.tagName).listen(
      (notes) => add(_TagDetailNotesUpdated(notes: notes, tagName: event.tagName)),
      onError: (error) => add(_TagDetailError(error.toString())),
    );
  }

  Future<void> _onNotesUpdated(_TagDetailNotesUpdated event, Emitter<TagDetailState> emit) async {
    emit(TagDetailLoaded(notes: event.notes, tagName: event.tagName));
  }

  Future<void> _onError(_TagDetailError event, Emitter<TagDetailState> emit) async {
    emit(TagDetailError(event.message));
  }

  @override
  Future<void> close() {
    _notesSubscription?.cancel();
    return super.close();
  }
}

// Internal Events
class _TagDetailNotesUpdated extends TagDetailEvent {
  final List<Note> notes;
  final String tagName;

  const _TagDetailNotesUpdated({required this.notes, required this.tagName});

  @override
  List<Object?> get props => [notes, tagName];
}

class _TagDetailError extends TagDetailEvent {
  final String message;

  const _TagDetailError(this.message);

  @override
  List<Object?> get props => [message];
} 