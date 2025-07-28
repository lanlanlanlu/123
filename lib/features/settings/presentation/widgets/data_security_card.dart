import 'package:flutter/material.dart';
import 'custom_dropdown_menu.dart' as custom;
import 'package:record_app/data/database/database.dart';
import 'package:record_app/data/database/connection/connection.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

class DataSecurityCard extends StatefulWidget {
  const DataSecurityCard({super.key});

  @override
  State<DataSecurityCard> createState() => _DataSecurityCardState();
}

class _DataSecurityCardState extends State<DataSecurityCard> {
  // 指纹安全开关状态
  bool _fingerprintEnabled = false;
  final Logger _logger = Logger();
  bool _isBackingUp = false;
  
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
          
          // 数据备份选项
          _buildNavigationItem(
            context,
            icon: Icons.backup,
            title: isZh ? '数据备份' : 'Backup Database',
            subtitle: isZh ? '执行检查点并备份数据库' : 'Run checkpoint and backup database',
            onTap: _isBackingUp ? null : () => _backupDatabase(context),
            trailing: _isBackingUp 
                ? SizedBox(
                    height: 24, 
                    width: 24, 
                    child: CircularProgressIndicator(strokeWidth: 2)
                  )
                : const Icon(Icons.chevron_right),
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
  
  // 执行数据库备份
  Future<void> _backupDatabase(BuildContext context) async {
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    
    try {
      setState(() {
        _isBackingUp = true;
      });
      
      // 获取数据库实例
      final database = Provider.of<AppDatabase>(context, listen: false);
      
      // 1. 执行WAL checkpoint，将所有日志合并到主数据库文件
      _logger.d('执行WAL checkpoint...');
      await database.customStatement('PRAGMA wal_checkpoint(FULL);');
      _logger.d('WAL checkpoint完成');
      
      // 2. 获取数据库文件路径
      final dbFolder = await getApplicationDocumentsDirectory();
      final dbPath = p.join(dbFolder.path, 'record.sqlite');
      final dbFile = File(dbPath);
      
      if (!dbFile.existsSync()) {
        throw '数据库文件不存在：$dbPath';
      }
      
      // 3. 创建一个备份目录
      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(p.join(appDir.path, 'backups'));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      
      // 4. 创建带时间戳的备份文件名
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
      final backupName = 'record_backup_$timestamp.sqlite';
      final backupPath = p.join(backupDir.path, backupName);
      
      // 5. 复制数据库文件到备份位置
      await dbFile.copy(backupPath);
      
      // 6. 分享备份文件
      final xFile = XFile(backupPath);
      await Share.shareXFiles(
        [xFile],
        text: isZh ? '记录应用数据库备份' : 'Record App Database Backup',
      );
      
      // 显示成功消息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isZh ? '数据库备份成功' : 'Database backup successful'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      _logger.d('数据库备份完成：$backupPath');
      
    } catch (e) {
      _logger.e('数据库备份失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isZh ? '备份失败：$e' : 'Backup failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isBackingUp = false;
      });
    }
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
    String? subtitle,
    required VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor.withOpacity(0.7)),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
        ),
      ),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
    );
  }
} 