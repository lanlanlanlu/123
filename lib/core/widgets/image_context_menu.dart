import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 图片上下文菜单回调类型
typedef ImageMenuCallback = void Function();

/// 自定义图片上下文菜单
class ImageContextMenu extends StatefulWidget {
  /// 菜单显示位置
  final Offset position;
  
  /// 小图模式回调
  final ImageMenuCallback? onThumbnailMode;
  
  /// 小图模式按钮文本
  final String thumbnailModeText;
  
  /// 复制回调
  final ImageMenuCallback? onCopy;
  
  /// 分享回调
  final ImageMenuCallback? onShare;
  
  /// 保存回调
  final ImageMenuCallback? onSave;
  
  /// 删除回调
  final ImageMenuCallback? onDelete;
  
  const ImageContextMenu({
    super.key,
    required this.position,
    this.onThumbnailMode,
    this.thumbnailModeText = '小图模式',
    this.onCopy,
    this.onShare,
    this.onSave,
    this.onDelete,
  });

  /// 显示图片上下文菜单
  static Future<void> show({
    required BuildContext context,
    required Offset position,
    ImageMenuCallback? onThumbnailMode,
    String thumbnailModeText = '小图模式',
    ImageMenuCallback? onCopy,
    ImageMenuCallback? onShare,
    ImageMenuCallback? onSave,
    ImageMenuCallback? onDelete,
  }) async {
    // 触发振动反馈
    HapticFeedback.lightImpact();
    
    // 显示菜单
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 80), // 更快的动画速度
      pageBuilder: (context, _, __) => ImageContextMenu(
        position: position,
        onThumbnailMode: onThumbnailMode,
        thumbnailModeText: thumbnailModeText,
        onCopy: onCopy,
        onShare: onShare,
        onSave: onSave,
        onDelete: onDelete,
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut, // 使用easeOut曲线使动画更流畅
          ),
          child: child,
        );
      },
    );
  }

  @override
  State<ImageContextMenu> createState() => _ImageContextMenuState();
}

class _ImageContextMenuState extends State<ImageContextMenu> {
  // 菜单宽度
  final double menuWidth = 120.0;
  // 菜单项高度
  final double itemHeight = 40.0;
  
  // 计算菜单高度
  double get menuHeight {
    int itemCount = 0;
    if (widget.onThumbnailMode != null) itemCount++;
    if (widget.onCopy != null) itemCount++;
    if (widget.onShare != null) itemCount++;
    if (widget.onSave != null) itemCount++;
    if (widget.onDelete != null) itemCount++;
    return itemHeight * itemCount;
  }
  
  // 计算菜单位置，确保不会出界
  Offset calculateMenuPosition(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    
    // 初始位置：菜单中心与点击位置对齐
    double left = widget.position.dx - menuWidth / 2;
    double top = widget.position.dy - menuHeight / 2;
    
    // 确保菜单不超出屏幕左右边界
    if (left < 10) {
      left = 10;
    } else if (left + menuWidth > screenSize.width - 10) {
      left = screenSize.width - menuWidth - 10;
    }
    
    // 确保菜单不超出屏幕上下边界
    if (top < 10) {
      top = 10;
    } else if (top + menuHeight > screenSize.height - 10) {
      top = screenSize.height - menuHeight - 10;
    }
    
    return Offset(left, top);
  }

  @override
  Widget build(BuildContext context) {
    final menuPosition = calculateMenuPosition(context);
    
    return Stack(
      children: [
        // 透明背景，用于点击关闭菜单
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(color: Colors.transparent),
          ),
        ),
        
        // 菜单内容
        Positioned(
          left: menuPosition.dx,
          top: menuPosition.dy,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: menuWidth,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95), // 白色背景，轻微透明
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.onThumbnailMode != null) _buildMenuItem(widget.thumbnailModeText, widget.onThumbnailMode!),
                    if (widget.onCopy != null) ...[
                      if (widget.onThumbnailMode != null) _buildDivider(),
                      _buildMenuItem('复制', widget.onCopy!),
                    ],
                    if (widget.onShare != null) ...[
                      if (widget.onThumbnailMode != null || widget.onCopy != null) _buildDivider(),
                      _buildMenuItem('分享', widget.onShare!),
                    ],
                    if (widget.onSave != null) ...[
                      if (widget.onThumbnailMode != null || widget.onCopy != null || widget.onShare != null) _buildDivider(),
                      _buildMenuItem('保存', widget.onSave!),
                    ],
                    if (widget.onDelete != null) ...[
                      if (widget.onThumbnailMode != null || widget.onCopy != null || widget.onShare != null || widget.onSave != null) _buildDivider(),
                      _buildMenuItem('删除', widget.onDelete!, isDestructive: true),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  // 构建菜单项
  Widget _buildMenuItem(String title, VoidCallback onTap, {bool isDestructive = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          onTap();
        },
        // 添加按下时的高亮效果
        highlightColor: Colors.black12,
        splashColor: Colors.transparent,
        child: Container(
          height: itemHeight,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          alignment: Alignment.centerLeft, // 左对齐
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: isDestructive ? Colors.red : Colors.black87,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
  
  // 构建分隔线
  Widget _buildDivider() {
    return const Divider(
      height: 0.5,
      thickness: 0.5,
      indent: 0,
      endIndent: 0,
      color: Color(0xFFD1D1D1), // 浅灰色分隔线
    );
  }
} 