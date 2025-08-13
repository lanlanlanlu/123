import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/settings_stats_bloc.dart';
import '../bloc/settings_stats_state.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class StatsSummaryCard extends StatelessWidget {
  const StatsSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsStatsBloc, SettingsStatsState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.error != null) {
          return Center(child: Text(state.error!));
        }

        final s = AppLocalizations.of(context)!;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 笔记数量
                _buildStatItem(
                  context, 
                  state.noteCount.toString(), 
                  s.statsNotes // 使用国际化的"笔记"/"Notes"
                ),
                
                // 字数
                _buildStatItem(
                  context, 
                  state.characterCount.toString(), 
                  s.statsChars // 使用国际化的"字数"/"Chars"
                ),
                
                // 天数
                _buildStatItem(
                  context, 
                  state.dayCount.toString(), 
                  s.statsDays // 使用国际化的"天数"/"Days"
                ),
                
                // 标签数
                _buildStatItem(
                  context, 
                  state.tagCount.toString(), 
                  s.tagsTitle // 使用"标签"/"Tags"
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildStatItem(BuildContext context, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
} 