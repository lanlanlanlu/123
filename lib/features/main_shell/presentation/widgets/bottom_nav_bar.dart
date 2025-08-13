import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// 底部导航栏组件
class BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const BottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return BottomAppBar(
      elevation: isDarkMode ? 2.0 : 8.0,
      notchMargin: 6.0,
      shape: const CircularNotchedRectangle(),
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shadowColor: isDarkMode ? Colors.black : Colors.black26,
      child: SizedBox(
        height: 56.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              context,
              index: 0,
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
              label: s.homeTabRecent,
            ),
            _buildNavItem(
              context,
              index: 1,
              icon: Icons.calendar_today_outlined,
              selectedIcon: Icons.calendar_today,
              label: s.calendarTitle,
            ),
            // 中间留空，用于FAB
            const SizedBox(width: 40),
            _buildNavItem(
              context,
              index: 2,
              icon: Icons.chat_outlined,
              selectedIcon: Icons.chat,
              label: s.aiChatTitle,
            ),
            _buildNavItem(
              context,
              index: 3,
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings,
              label: s.settingsTitle,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建单个导航项
  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    final bool isSelected = selectedIndex == index;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    // 选择颜色
    final Color selectedColor = theme.colorScheme.primary;
    final Color unselectedColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: () => onItemTapped(index),
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Icon(
            isSelected ? selectedIcon : icon,
            color: isSelected ? selectedColor : unselectedColor,
            size: 24,
          ),
        ),
      ),
    );
  }
} 