import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:record_app/main.dart';  // 导入LocaleCubit

class UserInterfaceCard extends StatefulWidget {
  const UserInterfaceCard({super.key});

  @override
  State<UserInterfaceCard> createState() => _UserInterfaceCardState();
}

class _UserInterfaceCardState extends State<UserInterfaceCard> {
  // 动态颜色开关状态
  bool _dynamicColorEnabled = true;
  // 主题模式和卡片行数
  String _themeMode = 'system';
  String _maxCardLines = '1000';

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 用户界面标题
          Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 16.0, right: 16.0, bottom: 8.0),
            child: Text(
              Localizations.localeOf(context).languageCode == 'zh'
                  ? '用户界面'
                  : 'User Interface',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // 动态颜色选项
          _buildSwitchItem(
            context,
            icon: Icons.palette,
            title: Localizations.localeOf(context).languageCode == 'zh'
                ? '动态颜色'
                : 'Dynamic Color',
            subtitle: Localizations.localeOf(context).languageCode == 'zh'
                ? '应用来自于主题的颜色'
                : 'Apply colors from theme',
            value: _dynamicColorEnabled,
            onChanged: (value) {
              setState(() {
                _dynamicColorEnabled = value;
              });
            },
          ),
          
          // 语言设置选项
          _buildSettingItem(
            context,
            icon: Icons.language,
            title: Localizations.localeOf(context).languageCode == 'zh'
                ? '语言'
                : 'Language',
            trailing: _buildLanguageDropdown(context),
          ),
          
          // 主题模式选项
          _buildSettingItem(
            context,
            icon: Icons.brightness_6,
            title: Localizations.localeOf(context).languageCode == 'zh'
                ? '主题模式'
                : 'Theme Mode',
            trailing: _buildThemeModeDropdown(context),
          ),
          
          // 首页卡片最大行数选项
          _buildSettingItem(
            context,
            icon: Icons.format_list_numbered,
            title: Localizations.localeOf(context).languageCode == 'zh'
                ? '首页卡片最大行数'
                : 'Max card lines',
            trailing: DropdownButton<String>(
              value: _maxCardLines,
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down),
              onChanged: (String? value) {
                if (value != null) {
                  setState(() {
                    _maxCardLines = value;
                  });
                }
              },
              items: ['500', '1000', '2000'].map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 8.0), // 底部间距
        ],
      ),
    );
  }
  
  // 构建通用设置项
  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor.withOpacity(0.7)),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
        ),
      ),
      trailing: trailing,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
    );
  }
  
  // 构建带开关的设置项
  Widget _buildSwitchItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor.withOpacity(0.7)),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[600],
        ),
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: Theme.of(context).primaryColor,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
    );
  }
  
  // 构建主题模式下拉菜单
  Widget _buildThemeModeDropdown(BuildContext context) {
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    
    return DropdownButton<String>(
      value: _themeMode,
      underline: const SizedBox(),
      icon: const Icon(Icons.arrow_drop_down),
      onChanged: (String? value) {
        if (value != null) {
          setState(() {
            _themeMode = value;
          });
        }
      },
      items: [
        DropdownMenuItem(
          value: 'system',
          child: Text(isZh ? '跟随系统' : 'Follow system'),
        ),
        DropdownMenuItem(
          value: 'light',
          child: Text(isZh ? '浅色' : 'Light'),
        ),
        DropdownMenuItem(
          value: 'dark',
          child: Text(isZh ? '深色' : 'Dark'),
        ),
      ],
    );
  }
  
  // 构建语言下拉菜单
  Widget _buildLanguageDropdown(BuildContext context) {
    final currentLocale = Localizations.localeOf(context).languageCode;
    
    return DropdownButton<String>(
      value: currentLocale,
      underline: const SizedBox(),
      icon: const Icon(Icons.arrow_drop_down),
      onChanged: (String? newValue) {
        if (newValue != null) {
          final newLocale = Locale(newValue);
          context.read<LocaleCubit>().changeLocale(newLocale);
        }
      },
      items: [
        DropdownMenuItem(
          value: 'zh',
          child: Text(
            currentLocale == 'zh' ? '中文' : 'Chinese',
          ),
        ),
        DropdownMenuItem(
          value: 'en',
          child: Text(
            currentLocale == 'zh' ? '英文' : 'English',
          ),
        ),
      ],
    );
  }
} 