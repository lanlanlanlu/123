import 'package:equatable/equatable.dart';

abstract class CalendarEvent extends Equatable {
  const CalendarEvent();

  @override
  List<Object?> get props => [];
}

class CalendarLoadNotes extends CalendarEvent {
  const CalendarLoadNotes();
}

class CalendarDateSelected extends CalendarEvent {
  final DateTime selectedDate;

  const CalendarDateSelected(this.selectedDate);

  @override
  List<Object?> get props => [selectedDate];
}

class CalendarMonthChanged extends CalendarEvent {
  final DateTime focusedMonth;

  const CalendarMonthChanged(this.focusedMonth);

  @override
  List<Object?> get props => [focusedMonth];
}

class CalendarGoToToday extends CalendarEvent {
  const CalendarGoToToday();
}