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
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
            ),
          );
        }

        if (state.error != null) {
          final isDarkMode = Theme.of(context).brightness == Brightness.dark;
          return Center(
            child: Text(
              state.error!,
              style: TextStyle(
                color: isDarkMode ? Colors.red[300] : Colors.red,
              ),
            ),
          );
        }

        final s = AppLocalizations.of(context)!;
        final theme = Theme.of(context);
        final isDarkMode = theme.brightness == Brightness.dark;

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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }
} 