import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:record_app/data/repository/notes_repository.dart';
import 'package:record_app/data/repository/tags_repository.dart';
import '../bloc/settings_heat_map_bloc.dart';
import '../bloc/settings_heat_map_event.dart';
import '../bloc/settings_stats_bloc.dart';
import '../bloc/settings_stats_event.dart';
import '../widgets/heat_map_chart_widget.dart';
import '../widgets/stats_summary_card.dart';
import '../widgets/user_interface_card.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          Localizations.localeOf(context).languageCode == 'zh' 
              ? '设置' 
              : 'Settings'
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 热力图区域 (移除了固定高度的SizedBox)
            BlocProvider(
              create: (context) => SettingsHeatMapBloc(
                notesRepository: context.read<NotesRepository>(),
              )..add(const LoadHeatMapData()),
              child: const HeatMapChartWidget(),
            ),
            
            // 统计摘要卡片
            BlocProvider(
              create: (context) => SettingsStatsBloc(
                notesRepository: context.read<NotesRepository>(),
                tagsRepository: context.read<TagsRepository>(),
              )..add(const LoadStatsData()),
              child: const StatsSummaryCard(),
            ),
            
            // 用户界面设置卡片 - 使用独立组件
            const UserInterfaceCard(),
          ],
        ),
      ),
    );
  }
}