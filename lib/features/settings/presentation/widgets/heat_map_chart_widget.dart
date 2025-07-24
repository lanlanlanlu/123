import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:intl/intl.dart';
import '../bloc/settings_heat_map_bloc.dart';

class HeatMapChartWidget extends StatefulWidget {
  const HeatMapChartWidget({super.key});

  @override
  State<HeatMapChartWidget> createState() => _HeatMapChartWidgetState();
}

class _HeatMapChartWidgetState extends State<HeatMapChartWidget> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsHeatMapBloc, SettingsHeatMapState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.error != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  state.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ),
          );
        }

        if (state.heatMapData.isEmpty) {
          return const Center(
            child: Text('暂无笔记创作数据'),
          );
        }

        // 创建HeatMap需要的数据格式
        final Map<DateTime, int> heatMapDataset = state.heatMapData;

        // 直接返回HeatMap组件，不添加任何额外容器
        return HeatMap(
          datasets: heatMapDataset,
          startDate: DateTime.now().subtract(const Duration(days: 365)),
          endDate: DateTime.now(),
          colorMode: ColorMode.color,
          defaultColor: Theme.of(context).brightness == Brightness.dark 
              ? Colors.grey[800]!
              : Colors.grey[200]!,
          textColor: Theme.of(context).colorScheme.onSurface,
          showText: false,
          showColorTip: true,
          colorTipCount: 10,
          colorTipSize: 11,
          scrollable: true,
          size: 14,
          borderRadius: 3,
          colorsets: const {
            1: Color(0xFF9BE9A8),  // 较少贡献
            3: Color(0xFF40C463),  // 中等贡献
            5: Color(0xFF30A14E),  // 较多贡献
            10: Color(0xFF216E39), // 大量贡献
          },
          onClick: (value) {
            if (value != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${DateFormat('yyyy-MM-dd').format(value)}: ${heatMapDataset[value] ?? 0} 笔记',
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          },
        );
      },
    );
  }
} 