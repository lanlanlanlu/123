import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:simple_heatmap_calendar/simple_heatmap_calendar.dart';
import '../bloc/settings_heat_map_bloc.dart';
import '../bloc/settings_heat_map_state.dart';

class HeatMapChartWidget extends StatefulWidget {
  const HeatMapChartWidget({super.key});

  @override
  State<HeatMapChartWidget> createState() => _HeatMapChartWidgetState();
}

class _HeatMapChartWidgetState extends State<HeatMapChartWidget> {
  // 【新增】创建一个我们自己控制的 ScrollController
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose(); // 释放ScrollController资源
    super.dispose();
  }
  
  // 获取本地化的日期格式
  String _getLocalizedDateFormat(BuildContext context, DateTime date) {
    final locale = Localizations.localeOf(context).languageCode;
    if (locale == 'zh') {
      // 中文日期格式: 2023年01月01日
      return '${date.year}年${date.month.toString().padLeft(2, '0')}月${date.day.toString().padLeft(2, '0')}日';
    } else {
      // 英文日期格式: yyyy-MM-dd
      return DateFormat('yyyy-MM-dd').format(date);
    }
  }

  // 获取本地化的笔记文本
  String _getLocalizedNoteText(BuildContext context, int count) {
    final locale = Localizations.localeOf(context).languageCode;
    if (locale == 'zh') {
      return '条笔记';
    } else {
      return count == 1 ? 'note' : 'notes';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsHeatMapBloc, SettingsHeatMapState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.error != null) {
          // ... 错误处理 ...
          return Center(child: Text(state.error!));
        }

        if (state.heatMapData.isEmpty) {
          return Center(
            child: Text(
              Localizations.localeOf(context).languageCode == 'zh'
                  ? '没有可用的笔记创建数据'
                  : 'No note creation data available'
            ),
          );
        }

        final Map<DateTime, num> heatMapDataset = state.heatMapData.cast<DateTime, num>();
        
        final theme = Theme.of(context);
        final currentYear = DateTime.now().year;
        final currentMonth = DateTime.now().month;
        final currentDay = DateTime.now().day;
        
        // 仍然使用稳定的全年范围来渲染
        final stableStartDate = DateTime(currentYear - 1, 1, 1);
        final stableEndedDate = DateTime(currentYear, currentMonth, currentDay);
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: HeatmapCalendar<num>(
            // 使用稳定的日期范围
            startDate: stableStartDate,
            endedDate: stableEndedDate,
            
            selectedMap: heatMapDataset,
            
            colorMap: {
              1: theme.primaryColor.withValues(alpha: 0.2),
              3: theme.primaryColor.withValues(alpha: 0.4),
              5: theme.primaryColor.withValues(alpha: 0.6),
              7: theme.primaryColor.withValues(alpha: 0.8),
              10: theme.primaryColor,
            },
            
            cellSize: const Size.square(16.0),
            colorTipCellSize: const Size.square(12.0),
            
            style: const HeatmapCalendarStyle.defaults(
              // cellPadding: EdgeInsets.all(2.5), // 使用 padding 代替 margin
              cellRadius: BorderRadius.all(Radius.circular(4.0)),
              weekLabelValueFontSize: 10.0,
              monthLabelFontSize: 12.0,
              // colorTipAlignBy: CalendarColorTipAlignBy.right,
            ),
            
            layoutParameters: const HeatmapLayoutParameters.defaults(
              monthLabelPosition: CalendarMonthLabelPosition.top,
              weekLabelPosition: CalendarWeekLabelPosition.right,
              colorTipPosition: CalendarColorTipPosition.bottom,
              // 【重要】移除 defaultScrollPosition，因为我们手动控制
            ),
            
            cellBuilder: (context, childBuilder, columnIndex, rowIndex, date) {
              final count = heatMapDataset[date] ?? 0;
              final notesString = _getLocalizedNoteText(context, count.toInt());
              return Tooltip(
                message: '${_getLocalizedDateFormat(context, date)}: $count $notesString',
                waitDuration: const Duration(milliseconds: 500),
                child: childBuilder(context),
              );
            },
          ),
        );
      },
    );
  }
}