import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'custom_dropdown_menu.dart' as custom;

class DataSecurityCard extends StatefulWidget {
  const DataSecurityCard({super.key});

  @override
  State<DataSecurityCard> createState() => _DataSecurityCardState();
}

class _DataSecurityCardState extends State<DataSecurityCard> {
  // 指纹安全开关状态
  bool _fingerprintEnabled = false;
  
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 数据与安全标题
          Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 16.0, right: 16.0, bottom: 8.0),
            child: Text(
              s.settingsDataAndSecurity,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
          
          // 指纹安全选项
          _buildSwitchItem(
            context,
            icon: Icons.fingerprint,
            title: s.settingsFingerprintSecurity,
            value: _fingerprintEnabled,
            onChanged: (value) {
              setState(() {
                _fingerprintEnabled = value;
              });
            },
          ),
          
          // 数据管理选项
          _buildNavigationItem(
            context,
            icon: Icons.storage,
            title: s.settingsDataManagement,
            onTap: () {
              // TODO: 导航到数据管理页面
            },
          ),
          
          // 随机漫步选项
          _buildNavigationItem(
            context,
            icon: Icons.shuffle,
            title: s.settingsRandomWalk,
            onTap: () {
              // TODO: 导航到随机漫步页面
            },
          ),
          
          // 相册浏览选项
          _buildNavigationItem(
            context,
            icon: Icons.photo_library,
            title: s.settingsPhotoGallery,
            onTap: () {
              // TODO: 导航到相册浏览页面
            },
          ),
          
          // 标签修正选项
          _buildNavigationItem(
            context,
            icon: Icons.label,
            title: s.settingsTagCorrection,
            onTap: () {
              // TODO: 导航到标签修正页面
            },
          ),
          
          const SizedBox(height: 8.0), // 底部间距
        ],
      ),
    );
  }
  
  // 构建带开关的设置项
  Widget _buildSwitchItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return ListTile(
      leading: Icon(
        icon, 
        color: isDarkMode 
            ? theme.colorScheme.primary.withOpacity(0.8)
            : theme.primaryColor.withOpacity(0.7),
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: theme.colorScheme.primary,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
    );
  }
  
  // 构建带导航箭头的设置项
  Widget _buildNavigationItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return ListTile(
      leading: Icon(
        icon, 
        color: isDarkMode 
            ? theme.colorScheme.primary.withOpacity(0.8)
            : theme.primaryColor.withOpacity(0.7),
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDarkMode ? Colors.white54 : Colors.black54,
        size: 20,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
    );
  }
} 