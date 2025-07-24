import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:record_app/main.dart';  // 导入LocaleCubit
import 'custom_dropdown_menu.dart' as custom;  // 导入自定义下拉菜单，使用别名

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
            trailing: _buildCustomDropdown(
              value: Localizations.localeOf(context).languageCode,
              onChanged: (value) {
                if (value != null) {
                  final newLocale = Locale(value);
                  context.read<LocaleCubit>().changeLocale(newLocale);
                }
              },
              items: [
                _buildDropdownItem('zh', Localizations.localeOf(context).languageCode == 'zh' ? '中文' : 'Chinese'),
                _buildDropdownItem('en', Localizations.localeOf(context).languageCode == 'zh' ? '英文' : 'English'),
              ],
              width: 120.0,
            ),
          ),
          
          // 主题模式选项
          _buildSettingItem(
            context,
            icon: Icons.brightness_6,
            title: Localizations.localeOf(context).languageCode == 'zh'
                ? '主题模式'
                : 'Theme Mode',
            trailing: _buildCustomDropdown(
              value: _themeMode,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _themeMode = value;
                  });
                }
              },
              items: [
                _buildDropdownItem(
                  'system', 
                  Localizations.localeOf(context).languageCode == 'zh' ? '跟随系统' : 'Follow system'
                ),
                _buildDropdownItem(
                  'light', 
                  Localizations.localeOf(context).languageCode == 'zh' ? '浅色' : 'Light'
                ),
                _buildDropdownItem(
                  'dark', 
                  Localizations.localeOf(context).languageCode == 'zh' ? '深色' : 'Dark'
                ),
              ],
              width: 150.0,
            ),
          ),
          
          // 首页卡片最大行数选项
          _buildSettingItem(
            context,
            icon: Icons.format_list_numbered,
            title: Localizations.localeOf(context).languageCode == 'zh'
                ? '首页卡片最大行数'
                : 'Max card lines',
            trailing: _buildCustomDropdown(
              value: _maxCardLines,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _maxCardLines = value;
                  });
                }
              },
              items: [
                _buildDropdownItem('500', '500'),
                _buildDropdownItem('1000', '1000'),
                _buildDropdownItem('2000', '2000'),
              ],
              width: 100.0,
            ),
          ),
          
          const SizedBox(height: 8.0), // 底部间距
        ],
      ),
    );
  }
  
  // 【核心修改】使用Builder来获取正确的context
  Widget _buildCustomDropdown<T>({
    required T value,
    required ValueChanged<T?> onChanged,
    required List<custom.DropdownMenuItem<T>> items,
    double? width,
  }) {
    return Builder(
      builder: (BuildContext context) {
        return GestureDetector(
          onTap: () async {
            final result = await custom.CustomDropdownMenu.show<T>(
              context: context,
              currentValue: value,
              items: items,
              width: width,
            );
            
            if (result != null) {
              onChanged(result);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  items.firstWhere((item) => item.value == value).title,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // 创建下拉项
  custom.DropdownMenuItem<T> _buildDropdownItem<T>(T value, String title) {
    return custom.DropdownMenuItem<T>(
      value: value,
      title: title,
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
}