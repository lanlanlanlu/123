import 'package:flutter/material.dart';

/// 底部导航栏组件
class BottomNavBar extends StatelessWidget {
  /// 当前选中的索引
  final int selectedIndex;

  /// 导航项点击回调
  final ValueChanged<int> onItemTapped;

  const BottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      elevation: 8.0, // 添加阴影效果增强视觉区分
      color: Colors.white, // 使用白色背景与上方灰色背景区分
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          IconButton(
            icon: Icon(
              Icons.home_outlined,
              color: selectedIndex == 0 
                  ? Theme.of(context).primaryColor 
                  : Colors.grey
            ),
            onPressed: () => onItemTapped(0),
          ),
          IconButton(
            icon: Icon(
              Icons.calendar_today_outlined,
              color: selectedIndex == 1 
                  ? Theme.of(context).primaryColor 
                  : Colors.grey
            ),
            onPressed: () => onItemTapped(1),
          ),
          const SizedBox(width: 48),
          IconButton(
            icon: Icon(
              Icons.explore_outlined,
              color: selectedIndex == 2 
                  ? Theme.of(context).primaryColor 
                  : Colors.grey
            ),
            onPressed: () => onItemTapped(2),
          ),
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: selectedIndex == 3 
                  ? Theme.of(context).primaryColor 
                  : Colors.grey
            ),
            onPressed: () => onItemTapped(3),
          ),
        ],
      ),
    );
  }
} 