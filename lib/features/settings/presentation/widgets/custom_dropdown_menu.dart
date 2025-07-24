import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 下拉菜单选项项
class DropdownMenuItem<T> {
  final T value;
  final String title;
  final bool isSelected;

  const DropdownMenuItem({
    required this.value,
    required this.title,
    this.isSelected = false,
  });
}

/// 通用可复用的下拉菜单
class CustomDropdownMenu {
  /// 显示下拉菜单
  static Future<T?> show<T>({
    required BuildContext context,
    required List<DropdownMenuItem<T>> items,
    required T currentValue,
    double? width,
    VoidCallback? onDismiss,
  }) async {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    
    // 获取按钮在屏幕中的位置和大小
    final buttonSize = button.size;
    final buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);
    
    // 计算菜单宽度
    final menuWidth = width ?? 120.0;
    
    HapticFeedback.lightImpact();
    
    // 显示菜单并返回选择的值
    return await showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 80),
      pageBuilder: (context, _, __) => _DropdownMenuWidget<T>(
        buttonPosition: buttonPosition,
        buttonSize: buttonSize,
        items: items,
        currentValue: currentValue,
        menuWidth: menuWidth,
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut), 
          child: child
        );
      },
    ).then((value) {
      // 调用关闭回调
      if (onDismiss != null) onDismiss();
      return value;
    });
  }
}

/// 下拉菜单组件
class _DropdownMenuWidget<T> extends StatelessWidget {
  final Offset buttonPosition;
  final Size buttonSize;
  final List<DropdownMenuItem<T>> items;
  final T currentValue;
  final double menuWidth;

  const _DropdownMenuWidget({
    required this.buttonPosition,
    required this.buttonSize,
    required this.items,
    required this.currentValue,
    required this.menuWidth,
  });

  double get _itemHeight => 40.0;
  // 菜单高度现在也考虑分隔线
  double get _menuHeight => (_itemHeight * items.length) + (items.length - 1);

  // 【核心修改】计算菜单位置，确保其相对于按钮正确定位
  Offset _calculateMenuPosition(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    // 1. 水平位置计算：让菜单中心与按钮中心对齐
    double left = buttonPosition.dx + (buttonSize.width / 2) - (menuWidth / 2);

    // 2. 垂直位置计算：优先在下方显示
    double top = buttonPosition.dy + buttonSize.height;

    // 检查下方空间是否足够
    if (top + _menuHeight > screenSize.height - 10) {
      // 如果下方空间不足，则在上方显示
      top = buttonPosition.dy - _menuHeight;
    }

    // 确保菜单不会超出屏幕左右边界
    if (left < 10) left = 10; 
    else if (left + menuWidth > screenSize.width - 10) left = screenSize.width - menuWidth - 10;
    
    // 确保菜单不会超出屏幕上下边界
    if (top < 10) top = 10;
    
    return Offset(left, top);
  }

  @override
  Widget build(BuildContext context) {
    final menuPosition = _calculateMenuPosition(context);
    
    return Stack(
      children: [
        // 透明背景，点击时关闭菜单
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
                color: Colors.white.withOpacity(0.95),
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
                  children: _buildMenuItems(context),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 构建菜单项列表
  List<Widget> _buildMenuItems(BuildContext context) {
    final widgets = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      widgets.add(_MenuItemWidget<T>(
        item: item,
        height: _itemHeight,
        currentValue: currentValue,
      ));
      
      // 添加分隔线，除了最后一项
      if (i != items.length - 1) {
        widgets.add(const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFD1D1D1)));
      }
    }
    return widgets;
  }
}

/// 菜单项组件
class _MenuItemWidget<T> extends StatelessWidget {
  final DropdownMenuItem<T> item;
  final double height;
  final T currentValue;
  
  const _MenuItemWidget({
    required this.item,
    required this.height,
    required this.currentValue,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelected = item.value == currentValue;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(item.value),
        highlightColor: Colors.black12,
        splashColor: Colors.transparent,
        child: Container(
          height: height,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check, size: 16, color: Colors.blue),
            ],
          ),
        ),
      ),
    );
  }
}