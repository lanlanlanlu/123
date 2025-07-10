import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 通用上下文菜单条目
class ContextMenuItem {
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const ContextMenuItem({
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });
}

/// 通用可复用的上下文菜单
class CommonContextMenu extends StatelessWidget {
  final Offset position;
  final List<ContextMenuItem> items;

  const CommonContextMenu({super.key, required this.position, required this.items});

  static Future<void> show({
    required BuildContext context,
    required Offset position,
    required List<ContextMenuItem> items,
  }) async {
    if (items.isEmpty) return;
    HapticFeedback.lightImpact();
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 80),
      pageBuilder: (context, _, __) => CommonContextMenu(position: position, items: items),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut), child: child);
      },
    );
  }

  double get _menuWidth => 120.0;
  double get _itemHeight => 40.0;

  double get _menuHeight => _itemHeight * items.length;

  Offset _calculateMenuPosition(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    double left = position.dx - _menuWidth / 2;
    double top = position.dy - _menuHeight / 2;
    if (left < 10) left = 10; else if (left + _menuWidth > screenSize.width - 10) left = screenSize.width - _menuWidth - 10;
    if (top < 10) top = 10; else if (top + _menuHeight > screenSize.height - 10) top = screenSize.height - _menuHeight - 10;
    return Offset(left, top);
  }

  @override
  Widget build(BuildContext context) {
    final menuPosition = _calculateMenuPosition(context);
    return Stack(children: [
      Positioned.fill(
        child: GestureDetector(onTap: () => Navigator.of(context).pop(), child: Container(color: Colors.transparent)),
      ),
      Positioned(
        left: menuPosition.dx,
        top: menuPosition.dy,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: _menuWidth,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Column(mainAxisSize: MainAxisSize.min, children: _buildMenuItems(context)),
            ),
          ),
        ),
      ),
    ]);
  }

  List<Widget> _buildMenuItems(BuildContext context) {
    final widgets = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      widgets.add(_MenuItemWidget(item: item, height: _itemHeight));
      if (i != items.length - 1) widgets.add(_divider);
    }
    return widgets;
  }

  Widget get _divider => const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFD1D1D1));
}

class _MenuItemWidget extends StatelessWidget {
  final ContextMenuItem item;
  final double height;
  const _MenuItemWidget({required this.item, required this.height});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          item.onTap();
        },
        highlightColor: Colors.black12,
        splashColor: Colors.transparent,
        child: Container(
          height: height,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          alignment: Alignment.centerLeft,
          child: Text(
            item.title,
            style: TextStyle(fontSize: 14, color: item.isDestructive ? Colors.red : Colors.black87),
          ),
        ),
      ),
    );
  }
} 