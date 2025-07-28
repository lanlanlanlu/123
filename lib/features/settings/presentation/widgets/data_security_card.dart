import 'package:flutter/material.dart';
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
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    
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
              isZh ? '数据与安全' : 'Data & Security',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // 指纹安全选项
          _buildSwitchItem(
            context,
            icon: Icons.fingerprint,
            title: isZh ? '指纹安全' : 'Fingerprint Security',
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
            title: isZh ? '数据管理' : 'Data Management',
            onTap: () {
              // TODO: 导航到数据管理页面
            },
          ),
          
          // 随机漫步选项
          _buildNavigationItem(
            context,
            icon: Icons.shuffle,
            title: isZh ? '随机漫步' : 'Random Walk',
            onTap: () {
              // TODO: 导航到随机漫步页面
            },
          ),
          
          // 相册浏览选项
          _buildNavigationItem(
            context,
            icon: Icons.photo_library,
            title: isZh ? '相册浏览' : 'Photo Gallery',
            onTap: () {
              // TODO: 导航到相册浏览页面
            },
          ),
          
          // 标签修正选项
          _buildNavigationItem(
            context,
            icon: Icons.label,
            title: isZh ? '标签修正' : 'Tag Correction',
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
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor.withOpacity(0.7)),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
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
  
  // 构建带导航箭头的设置项
  Widget _buildNavigationItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor.withOpacity(0.7)),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
    );
  }
} 