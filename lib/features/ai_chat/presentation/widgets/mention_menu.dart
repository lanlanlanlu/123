import 'package:flutter/material.dart';
import 'package:record_app/core/widgets/context_menu.dart';

/// 表示可在聊天中@的项目类型
enum MentionType {
  note,
  tag,
  location,
}

/// @菜单项目
class MentionItem {
  final String id;
  final String title;
  final MentionType type;

  const MentionItem({
    required this.id,
    required this.title,
    required this.type,
  });
}

/// @菜单控制器，用于管理菜单的显示和隐藏
class MentionMenuController {
  OverlayEntry? _overlayEntry;
  bool get isShowing => _overlayEntry != null;

  void hide() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }

  void dispose() {
    hide();
  }
}

/// @菜单组件
class MentionMenu extends StatefulWidget {
  final Offset position;
  final Offset buttonPosition; // @按钮的位置
  final Function(MentionItem) onItemSelected;
  final Function(String) onSearchSubmitted;
  final double inputBoxHeight;
  final bool autofocus; // 控制是否自动获取焦点

  const MentionMenu({
    Key? key,
    required this.position,
    required this.buttonPosition,
    required this.onItemSelected,
    required this.onSearchSubmitted,
    this.inputBoxHeight = 48.0,
    this.autofocus = false, // 默认不自动获取焦点
  }) : super(key: key);

  /// 显示菜单，返回一个控制器
  static MentionMenuController show({
    required BuildContext context,
    required Offset position,
    required Offset buttonPosition,
    required Function(MentionItem) onItemSelected,
    required Function(String) onSearchSubmitted,
    double inputBoxHeight = 48.0,
    bool autofocus = false,
  }) {
    final controller = MentionMenuController();
    final OverlayState overlayState = Overlay.of(context);

    controller._overlayEntry = OverlayEntry(
      builder: (context) => _MentionMenuOverlay(
        controller: controller,
        position: position,
        buttonPosition: buttonPosition,
        onItemSelected: onItemSelected,
        onSearchSubmitted: onSearchSubmitted,
        inputBoxHeight: inputBoxHeight,
        autofocus: autofocus,
      ),
    );

    overlayState.insert(controller._overlayEntry!);
    return controller;
  }

  @override
  State<MentionMenu> createState() => _MentionMenuState();
}

/// 菜单覆盖层，处理点击外部关闭菜单
class _MentionMenuOverlay extends StatelessWidget {
  final MentionMenuController controller;
  final Offset position;
  final Offset buttonPosition;
  final Function(MentionItem) onItemSelected;
  final Function(String) onSearchSubmitted;
  final double inputBoxHeight;
  final bool autofocus;

  const _MentionMenuOverlay({
    Key? key,
    required this.controller,
    required this.position,
    required this.buttonPosition,
    required this.onItemSelected,
    required this.onSearchSubmitted,
    required this.inputBoxHeight,
    required this.autofocus,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => controller.hide(),
      child: Stack(
        children: [
          _MentionMenuContent(
            position: position,
            buttonPosition: buttonPosition,
            onItemSelected: onItemSelected,
            onSearchSubmitted: onSearchSubmitted,
            inputBoxHeight: inputBoxHeight,
            autofocus: autofocus,
            controller: controller,
          ),
        ],
      ),
    );
  }
}

/// 菜单内容组件
class _MentionMenuContent extends StatefulWidget {
  final Offset position;
  final Offset buttonPosition;
  final Function(MentionItem) onItemSelected;
  final Function(String) onSearchSubmitted;
  final double inputBoxHeight;
  final bool autofocus;
  final MentionMenuController controller;

  const _MentionMenuContent({
    Key? key,
    required this.position,
    required this.buttonPosition,
    required this.onItemSelected,
    required this.onSearchSubmitted,
    required this.inputBoxHeight,
    required this.autofocus,
    required this.controller,
  }) : super(key: key);

  @override
  State<_MentionMenuContent> createState() => _MentionMenuContentState();
}

class _MentionMenuContentState extends State<_MentionMenuContent> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // 只有在明确指定autofocus为true时才请求焦点
    if (widget.autofocus) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // 菜单宽度和位置计算
  double get _menuWidth => 220.0;
  double get _menuMaxHeight => 280.0;
  double get _menuGap => 2.0; // 减小菜单与输入框之间的缝隙

  Offset _calculateMenuPosition(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final EdgeInsets padding = MediaQuery.of(context).padding;
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    // 输入框顶部位置
    final inputBoxTop = widget.position.dy;

    // 菜单底部位置应该刚好在输入框顶部上方，留有很小的缝隙
    final menuBottom = inputBoxTop - _menuGap;

    // 菜单高度可能需要根据可用空间调整
    double menuHeight = _menuMaxHeight;

    // 如果菜单顶部太靠近屏幕顶部，调整菜单高度
    if (menuBottom - menuHeight < padding.top) {
      menuHeight = menuBottom - padding.top - 10; // 至少留10px的上边距
      if (menuHeight < 100) menuHeight = 100;      // 确保菜单至少有100px高
    }

    // 计算菜单顶部位置
    final menuTop = menuBottom - menuHeight;

    // 使菜单左侧与@按钮左侧对齐
    // 由于@按钮坐标是按钮的左上角，我们直接使用这个坐标
    double left = widget.buttonPosition.dx;

    // 确保菜单在屏幕水平范围内
    if (left < 10) {
      left = 10;
    } else if (left + _menuWidth > screenSize.width - 10) {
      left = screenSize.width - _menuWidth - 10;
    }

    return Offset(left, menuTop < padding.top ? padding.top : menuTop);
  }

  @override
  Widget build(BuildContext context) {
    final menuPosition = _calculateMenuPosition(context);

    return Positioned(
      left: menuPosition.dx,
      top: menuPosition.dy,
      child: GestureDetector(
        // 阻止点击事件冒泡到外层
        onTap: () {},
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: _menuWidth,
            constraints: BoxConstraints(
              maxHeight: _menuMaxHeight,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 固定选项
                  _buildMenuOption(
                    icon: Icons.note,
                    title: '笔记',
                    onTap: () {
                      widget.controller.hide();
                      widget.onItemSelected(
                        const MentionItem(
                          id: 'notes',
                          title: '笔记',
                          type: MentionType.note,
                        ),
                      );
                    },
                  ),
                  _divider,
                  _buildMenuOption(
                    icon: Icons.label,
                    title: '标签',
                    onTap: () {
                      widget.controller.hide();
                      widget.onItemSelected(
                        const MentionItem(
                          id: 'tags',
                          title: '标签',
                          type: MentionType.tag,
                        ),
                      );
                    },
                  ),
                  _divider,
                  _buildMenuOption(
                    icon: Icons.location_on,
                    title: '地点',
                    onTap: () {
                      widget.controller.hide();
                      widget.onItemSelected(
                        const MentionItem(
                          id: 'locations',
                          title: '地点',
                          type: MentionType.location,
                        ),
                      );
                    },
                  ),
                  _divider,
                  // 搜索输入框
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        hintText: '添加笔记，地点，标签...',
                        hintStyle: TextStyle(fontSize: 14, color: Colors.black38),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 14),
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          widget.controller.hide();
                          widget.onSearchSubmitted(value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.black54),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget get _divider => const Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE));
}

class _MentionMenuState extends State<MentionMenu> {
  @override
  Widget build(BuildContext context) {
    return Container(); // 这个状态类实际上不会被使用，因为我们使用OverlayEntry
  }
}