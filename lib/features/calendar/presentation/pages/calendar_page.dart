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
        final selectedDate = state.selectedDate;
        final now = DateTime.now();
        final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
        final weekdayText = weekdays[selectedDate.weekday - 1];

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          // 【修改】使用标准 AppBar，并将所有自定义内容放入 title
          appBar: AppBar(
            automaticallyImplyLeading: false,
            titleSpacing: 16.0,
            title: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 左侧日期组合
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${selectedDate.month}月${selectedDate.day}日',
                      style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${selectedDate.year}',
                            style: TextStyle(
                              color: Theme.of(context).appBarTheme.foregroundColor,
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          Text(
                            weekdayText,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // 右侧“今天”按钮
                _TodayButton(today: now),
              ],
            ),
          ),
          body: Column(
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

// “今天”按钮的内部实现，从旧的 header 文件中移入
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