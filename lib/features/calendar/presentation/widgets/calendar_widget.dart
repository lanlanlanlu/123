import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:table_calendar/table_calendar.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';

class CalendarWidget extends StatelessWidget {
  final CalendarState state;
  
  const CalendarWidget({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    
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
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.textTheme.titleLarge?.color,
          ),
          leftChevronIcon: Icon(Icons.chevron_left, color: theme.iconTheme.color),
          rightChevronIcon: Icon(Icons.chevron_right, color: theme.iconTheme.color),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
          weekendStyle: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: true,
          // 根据主题设置文本颜色
          defaultTextStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
          weekendTextStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
          holidayTextStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
          outsideTextStyle: TextStyle(color: isDarkMode ? Colors.grey[600] : Colors.grey[400]),
          
          // 选中日期的装饰
          selectedDecoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.8),
            shape: BoxShape.circle,
          ),
          selectedTextStyle: TextStyle(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
          
          // 今天的装饰
          todayDecoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
            shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
          
          // 事件标记的装饰
          markerDecoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
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