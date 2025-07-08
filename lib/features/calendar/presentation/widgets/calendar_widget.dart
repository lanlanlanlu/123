import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:table_calendar/table_calendar.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';

class CalendarWidget extends StatelessWidget {
  final CalendarState state;
  
  const CalendarWidget({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: TableCalendar<String>(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: state.focusedDate,
        selectedDayPredicate: (day) {
          return isSameDay(state.selectedDate, day);
        },
        calendarFormat: CalendarFormat.month,
        startingDayOfWeek: StartingDayOfWeek.monday,
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          leftChevronIcon: Icon(Icons.chevron_left),
          rightChevronIcon: Icon(Icons.chevron_right),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
          weekendStyle: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: true,
          weekendTextStyle: const TextStyle(color: Colors.black87),
          holidayTextStyle: const TextStyle(color: Colors.black87),
          selectedDecoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.8),
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: Colors.grey[300],
            shape: BoxShape.circle,
          ),
          markerDecoration: BoxDecoration(
            color: Colors.grey[500],
            shape: BoxShape.circle,
          ),
          markerSize: 6.0,
          markersMaxCount: 1,
          canMarkersOverflow: false,
        ),
        eventLoader: (day) {
          final dateKey = DateTime(day.year, day.month, day.day);
          final notes = state.notesByDate[dateKey] ?? [];
          return notes.isNotEmpty ? [''] : [];
        },
        onDaySelected: (selectedDay, focusedDay) {
          context.read<CalendarBloc>().add(CalendarDateSelected(selectedDay));
        },
        onPageChanged: (focusedDay) {
          context.read<CalendarBloc>().add(CalendarMonthChanged(focusedDay));
        },
      ),
    );
  }
}