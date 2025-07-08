import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../data/repository/repository.dart';
import '../../../../data/database/database.dart';
import 'calendar_event.dart';
import 'calendar_state.dart';

class CalendarBloc extends Bloc<CalendarEvent, CalendarState> {
  final Repository repository;

  CalendarBloc({required this.repository})
      : super(CalendarState(
          selectedDate: DateTime.now(),
          focusedDate: DateTime.now(),
        )) {
    on<CalendarLoadNotes>(_onLoadNotes);
    on<CalendarDateSelected>(_onDateSelected);
    on<CalendarMonthChanged>(_onMonthChanged);
    on<CalendarGoToToday>(_onGoToToday);
  }

  Future<void> _onLoadNotes(
    CalendarLoadNotes event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      emit(state.copyWith(isLoading: true, error: null));

      final notes = await repository.getAllNotes();
      final notesByDate = <DateTime, List<Note>>{};

      for (final note in notes) {
        final dateKey = DateTime(
          note.createdAt.year,
          note.createdAt.month,
          note.createdAt.day,
        );

        if (notesByDate.containsKey(dateKey)) {
          notesByDate[dateKey]!.add(note);
        } else {
          notesByDate[dateKey] = [note];
        }
      }

      final selectedDateNotes = notesByDate[DateTime(
            state.selectedDate.year,
            state.selectedDate.month,
            state.selectedDate.day,
          )] ??
          [];

      emit(state.copyWith(
        notesByDate: notesByDate,
        selectedDateNotes: selectedDateNotes,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        error: e.toString(),
        isLoading: false,
      ));
    }
  }

  Future<void> _onDateSelected(
    CalendarDateSelected event,
    Emitter<CalendarState> emit,
  ) async {
    final selectedDateKey = DateTime(
      event.selectedDate.year,
      event.selectedDate.month,
      event.selectedDate.day,
    );

    final notesForDate = state.notesByDate[selectedDateKey] ?? [];

    emit(state.copyWith(
      selectedDate: event.selectedDate,
      selectedDateNotes: notesForDate,
    ));
  }

  Future<void> _onMonthChanged(
    CalendarMonthChanged event,
    Emitter<CalendarState> emit,
  ) async {
    emit(state.copyWith(focusedDate: event.focusedMonth));
  }

  Future<void> _onGoToToday(
    CalendarGoToToday event,
    Emitter<CalendarState> emit,
  ) async {
    final today = DateTime.now();
    final todayKey = DateTime(
      today.year,
      today.month,
      today.day,
    );

    final notesForToday = state.notesByDate[todayKey] ?? [];

    emit(state.copyWith(
      selectedDate: today,
      focusedDate: today,
      selectedDateNotes: notesForToday,
    ));
  }
}