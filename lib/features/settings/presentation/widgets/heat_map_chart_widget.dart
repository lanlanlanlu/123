import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:simple_heatmap_calendar/simple_heatmap_calendar.dart';
import '../bloc/settings_heat_map_bloc.dart';
import '../bloc/settings_heat_map_state.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
    final s = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return BlocBuilder<SettingsHeatMapBloc, SettingsHeatMapState>(
      builder: (context, state) {
        if (state.isLoading) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          );
        }

        if (state.error != null) {
          // ... 错误处理 ...
          return Center(
            child: Text(
              state.error!,
              style: TextStyle(
                color: isDarkMode ? Colors.red[300] : Colors.red,
              ),
            ),
          );
        }

        if (state.heatMapData.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                s.heatMapNoData,
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),
          );
        }

        final Map<DateTime, num> heatMapDataset = state.heatMapData.cast<DateTime, num>();
        
        final currentYear = DateTime.now().year;
        final currentMonth = DateTime.now().month;
        final currentDay = DateTime.now().day;
        
        // 仍然使用稳定的全年范围来渲染
        final stableStartDate = DateTime(currentYear - 1, 1, 1);
        final stableEndedDate = DateTime(currentYear, currentMonth, currentDay);
        
        // 根据当前主题模式选择合适的颜色
        final primaryColor = theme.colorScheme.primary;
        final colorMap = isDarkMode 
            ? {
                1: primaryColor.withOpacity(0.3),
                3: primaryColor.withOpacity(0.5),
                5: primaryColor.withOpacity(0.7),
                7: primaryColor.withOpacity(0.85),
                10: primaryColor,
              }
            : {
                1: primaryColor.withOpacity(0.2),
                3: primaryColor.withOpacity(0.4),
                5: primaryColor.withOpacity(0.6),
                7: primaryColor.withOpacity(0.8),
                10: primaryColor,
              };
        
        // 设置空单元格颜色
        final emptyColor = isDarkMode ? Colors.grey[800] : Colors.grey[200];
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: HeatmapCalendar<num>(
            // 使用稳定的日期范围
            startDate: stableStartDate,
            endedDate: stableEndedDate,
            
            selectedMap: heatMapDataset,
            
            colorMap: colorMap,
            
            cellSize: const Size.square(16.0),
            colorTipCellSize: const Size.square(12.0),
            
            style: HeatmapCalendarStyle.defaults(
              cellRadius: const BorderRadius.all(Radius.circular(4.0)),
              weekLabelValueFontSize: 10.0,
              monthLabelFontSize: 12.0,
              // 注意：HeatmapCalendarStyle.defaults 不支持 defaultColor 和 textColor
              // 我们可以通过自定义主题或其他方式解决
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