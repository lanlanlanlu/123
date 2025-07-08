// lib/features/calendar/presentation/pages/calendar_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../data/repository/repository.dart';
import '../widgets/calendar_widget.dart';
import '../widgets/calendar_notes_list.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';

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
    return BlocBuilder<CalendarBloc, CalendarState>(
      builder: (context, state) {
        // 移除Scaffold，只保留body部分
        return Container(
          color: Colors.grey[50], // 与AppBar保持一致的背景色
          child: Column(
            children: [
              CalendarWidget(state: state),
              Expanded(
                child: CalendarNotesList(state: state),
              ),
            ],
          ),
        );
      },
    );
  }
}

// "今天"按钮的内部实现，从旧的 header 文件中移入
class _TodayButton extends StatelessWidget {
  final DateTime today;

  const _TodayButton({required this.today});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[400]!, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            context.read<CalendarBloc>().add(const CalendarGoToToday());
          },
          child: Center(
            child: Text(
              '${today.day}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).appBarTheme.foregroundColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}