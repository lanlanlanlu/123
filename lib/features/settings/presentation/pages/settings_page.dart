import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:record_app/data/repository/notes_repository.dart';
import '../bloc/settings_heat_map_bloc.dart';
import '../widgets/heat_map_chart_widget.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // 【修改】直接在页面内定义AppBar，不再依赖外部
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true, // 标题居中
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: BlocProvider(
        create: (context) => SettingsHeatMapBloc(
          notesRepository: context.read<NotesRepository>(),
        )..add(const LoadHeatMapData()),
        // 【核心修改】直接返回热力图组件，移除了所有不必要的Stack和Positioned包装
        child: const HeatMapChartWidget(),
      ),
    );
  }
}