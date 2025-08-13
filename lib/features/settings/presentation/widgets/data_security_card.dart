import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:record_app/core/services/auth_service.dart';
import 'custom_dropdown_menu.dart' as custom;
import 'dart:io' show Platform;

class DataSecurityCard extends StatefulWidget {
  const DataSecurityCard({super.key});

  @override
  State<DataSecurityCard> createState() => _DataSecurityCardState();
}

class _DataSecurityCardState extends State<DataSecurityCard> {
  // 指纹安全开关状态
  bool _fingerprintEnabled = false;
  bool _isLoading = true;
  final BiometricAuthService _authService = BiometricAuthService();
  
  @override
  void initState() {
    super.initState();
    // 初始化时加载指纹认证状态
    _loadBiometricState();
  }
  
  // 加载生物识别状态
  Future<void> _loadBiometricState() async {
    final isEnabled = await _authService.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _fingerprintEnabled = isEnabled;
        _isLoading = false;
      });
    }
  }
  
  // 切换指纹认证状态
  Future<void> _toggleFingerprint(bool value) async {
    // 获取本地化字符串，如果不可用则使用默认值
    String notSupportedMessage = '您的设备不支持生物识别验证';
    
    try {
      final s = AppLocalizations.of(context);
      if (s != null) {
        notSupportedMessage = s.authBiometricNotSupported;
      }
    } catch (e) {
      debugPrint('获取本地化资源失败: $e');
    }
    
    // 检查设备是否支持生物认证
    final isAvailable = await _authService.isBiometricAvailable();
    if (!isAvailable) {
      if (mounted) {
        _showErrorDialog(notSupportedMessage);
      }
      return;
    }
    
    // 检测是否为Windows平台
    bool isWindows = false;
    try {
      isWindows = Platform.isWindows;
    } catch (e) {
      debugPrint('平台检测失败: $e');
    }
    
    // 如果当前已启用，需要先验证身份才能关闭
    if (_fingerprintEnabled) {
      final authenticated = await _authService.authenticate(context);
      if (!authenticated) return;
    }
    
    // 如果要启用，也需要先验证身份
    if (!_fingerprintEnabled && value) {
      // 在Windows平台上，如果刚刚已经验证过，就不再重复验证
      if (!isWindows) {
        final authenticated = await _authService.authenticate(context);
        if (!authenticated) return;
      }
    }
    
    // 更新状态
    await _authService.setBiometricEnabled(value);
    if (mounted) {
      setState(() {
        _fingerprintEnabled = value;
      });
    }
  }
  
  // 显示错误对话框
  void _showErrorDialog(String message) {
    // 获取本地化字符串，如果不可用则使用默认值
    String errorTitle = '认证错误';
    String okButton = '确定';
    
    try {
      final s = AppLocalizations.of(context);
      if (s != null) {
        errorTitle = s.authBiometricError;
        okButton = s.ok;
      }
    } catch (e) {
      debugPrint('获取本地化资源失败: $e');
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(errorTitle),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(okButton),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    // 获取本地化字符串，如果不可用则使用默认值
    String dataAndSecurity = '数据与安全';
    String fingerprintSecurity = '指纹安全';
    String dataManagement = '数据管理';
    String randomWalk = '随机漫步';
    String photoGallery = '相册浏览';
    String tagCorrection = '标签修正';
    
    try {
      final s = AppLocalizations.of(context);
      if (s != null) {
        dataAndSecurity = s.settingsDataAndSecurity;
        fingerprintSecurity = s.settingsFingerprintSecurity;
        dataManagement = s.settingsDataManagement;
        randomWalk = s.settingsRandomWalk;
        photoGallery = s.settingsPhotoGallery;
        tagCorrection = s.settingsTagCorrection;
      }
    } catch (e) {
      debugPrint('获取本地化资源失败: $e');
    }
    
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
              dataAndSecurity,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
          
          // 指纹安全选项
          _isLoading
              ? _buildLoadingItem(context)
              : _buildSwitchItem(
            context,
            icon: Icons.fingerprint,
                  title: fingerprintSecurity,
            value: _fingerprintEnabled,
                  onChanged: _toggleFingerprint,
          ),
          
          // 数据管理选项
          _buildNavigationItem(
            context,
            icon: Icons.storage,
            title: dataManagement,
            onTap: () {
              // TODO: 导航到数据管理页面
            },
          ),
          
          // 随机漫步选项
          _buildNavigationItem(
            context,
            icon: Icons.shuffle,
            title: randomWalk,
            onTap: () {
              // TODO: 导航到随机漫步页面
            },
          ),
          
          // 相册浏览选项
          _buildNavigationItem(
            context,
            icon: Icons.photo_library,
            title: photoGallery,
            onTap: () {
              // TODO: 导航到相册浏览页面
            },
          ),
          
          // 标签修正选项
          _buildNavigationItem(
            context,
            icon: Icons.label,
            title: tagCorrection,
            onTap: () {
              // TODO: 导航到标签修正页面
            },
          ),
          
          const SizedBox(height: 8.0), // 底部间距
        ],
      ),
    );
  }
  
  // 构建加载中的设置项
  Widget _buildLoadingItem(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    // 获取本地化字符串，如果不可用则使用默认值
    String fingerprintSecurity = '指纹安全';
    
    try {
      final s = AppLocalizations.of(context);
      if (s != null) {
        fingerprintSecurity = s.settingsFingerprintSecurity;
      }
    } catch (e) {
      debugPrint('获取本地化资源失败: $e');
    }
    
    return ListTile(
      leading: Icon(
        Icons.fingerprint, 
        color: isDarkMode 
            ? theme.colorScheme.primary.withOpacity(0.8)
            : theme.primaryColor.withOpacity(0.7),
        size: 22,
      ),
      title: Text(
        fingerprintSecurity,
        style: TextStyle(
          fontSize: 16,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      trailing: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            isDarkMode ? Colors.white70 : Colors.grey[700]!,
          ),
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
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