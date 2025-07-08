import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../../data/repository/repository.dart';
import '../../../home/presentation/widgets/note_list.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../../../../core/utils/date_format_helper.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CalendarBloc(
        repository: context.read<Repository>(),
      )..add(const CalendarLoadNotes()),
      child: const CalendarView(),
    );
  }
}

class CalendarView extends StatelessWidget {
  const CalendarView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<CalendarBloc, CalendarState>(
          builder: (context, state) {
            return Column(
              children: [
                _buildHeader(context, state),
                _buildCalendar(context, state),
                const Divider(height: 1),
                Expanded(
                  child: _buildNotesList(context, state),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, CalendarState state) {
    final dateFormat = DateFormatHelper.getMonthDayFormat(context);
    final weekdayFormat = DateFormatHelper.getWeekdayFormat(context);
    final yearFormat = DateFormatHelper.getYearFormat(context);

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      dateFormat.format(state.selectedDate),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      yearFormat.format(state.selectedDate),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                Text(
                  weekdayFormat.format(state.selectedDate),
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.today),
            iconSize: 28,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(BuildContext context, CalendarState state) {
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
          markerDecoration: const BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          markersMaxCount: 3,
          canMarkersOverflow: false,
        ),
        eventLoader: (day) {
          final dateKey = DateTime(day.year, day.month, day.day);
          final notes = state.notesByDate[dateKey] ?? [];
          return List.generate(notes.length, (index) => '');
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

  Widget _buildNotesList(BuildContext context, CalendarState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Text(
          '加载失败: ${state.error}',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (state.selectedDateNotes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'NoThing ~',
              style: TextStyle(
                fontSize: 24,
                color: Colors.grey,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      );
    }

    return NoteList(
      notes: state.selectedDateNotes,
      onNoteTogglePin: (note) {
        // TODO: 实现置顶功能
      },
      onNoteDelete: (note) {
        // TODO: 实现删除功能
      },
    );
  }
}