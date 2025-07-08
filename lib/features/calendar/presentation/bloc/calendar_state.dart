import 'package:equatable/equatable.dart';
import '../../../../data/database/database.dart';

class CalendarState extends Equatable {
  final DateTime selectedDate;
  final DateTime focusedDate;
  final Map<DateTime, List<Note>> notesByDate;
  final List<Note> selectedDateNotes;
  final bool isLoading;
  final String? error;

  const CalendarState({
    required this.selectedDate,
    required this.focusedDate,
    this.notesByDate = const {},
    this.selectedDateNotes = const [],
    this.isLoading = false,
    this.error,
  });

  CalendarState copyWith({
    DateTime? selectedDate,
    DateTime? focusedDate,
    Map<DateTime, List<Note>>? notesByDate,
    List<Note>? selectedDateNotes,
    bool? isLoading,
    String? error,
  }) {
    return CalendarState(
      selectedDate: selectedDate ?? this.selectedDate,
      focusedDate: focusedDate ?? this.focusedDate,
      notesByDate: notesByDate ?? this.notesByDate,
      selectedDateNotes: selectedDateNotes ?? this.selectedDateNotes,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [
        selectedDate,
        focusedDate,
        notesByDate,
        selectedDateNotes,
        isLoading,
        error,
      ];
}