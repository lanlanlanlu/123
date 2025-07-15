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
  final LayerLink layerLink; // 用于与输入框连接的链接
  final double verticalOffset; // 菜单与输入框之间的垂直偏移量
  final double horizontalOffset; // 菜单与输入框之间的水平偏移量
  final double menuWidth; // 菜单宽度
  final double inputBoxHeight; // 输入框高度
  final Function(MentionItem) onItemSelected;
  final Function(String) onSearchSubmitted;
  final bool autofocus; // 控制是否自动获取焦点

  const MentionMenu({
    Key? key,
    required this.layerLink,
    this.verticalOffset = -2.0, // 默认向上偏移2像素，可以设为0实现无缝连接
    this.horizontalOffset = 0.0, // 默认不水平偏移
    this.menuWidth = 220.0,
    required this.onItemSelected,
    required this.onSearchSubmitted,
    this.inputBoxHeight = 48.0,
    this.autofocus = false, // 默认不自动获取焦点
  }) : super(key: key);

  /// 显示菜单，返回一个控制器
  static MentionMenuController show({
    required BuildContext context,
    required LayerLink layerLink,
    required Function(MentionItem) onItemSelected,
    required Function(String) onSearchSubmitted,
    double verticalOffset = -2.0, // 默认向上偏移2像素，使其刚好位于输入框上方
    double horizontalOffset = 0.0, // 默认不水平偏移
    double menuWidth = 220.0,
    double inputBoxHeight = 48.0,
    bool autofocus = false,
  }) {
    final controller = MentionMenuController();
    final OverlayState overlayState = Overlay.of(context);
    
    controller._overlayEntry = OverlayEntry(
      builder: (context) => _MentionMenuOverlay(
        controller: controller,
        layerLink: layerLink,
        verticalOffset: verticalOffset,
        horizontalOffset: horizontalOffset,
        menuWidth: menuWidth,
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
  final LayerLink layerLink;
  final double verticalOffset;
  final double horizontalOffset;
  final double menuWidth;
  final Function(MentionItem) onItemSelected;
  final Function(String) onSearchSubmitted;
  final double inputBoxHeight;
  final bool autofocus;
  
  const _MentionMenuOverlay({
    Key? key,
    required this.controller,
    required this.layerLink,
    required this.verticalOffset,
    required this.horizontalOffset,
    required this.menuWidth,
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
            layerLink: layerLink,
            verticalOffset: verticalOffset,
            horizontalOffset: horizontalOffset,
            menuWidth: menuWidth,
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
  final LayerLink layerLink;
  final double verticalOffset;
  final double horizontalOffset;
  final double menuWidth;
  final Function(MentionItem) onItemSelected;
  final Function(String) onSearchSubmitted;
  final double inputBoxHeight;
  final bool autofocus;
  final MentionMenuController controller;
  
  const _MentionMenuContent({
    Key? key,
    required this.layerLink,
    required this.verticalOffset,
    required this.horizontalOffset,
    required this.menuWidth,
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

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final EdgeInsets padding = MediaQuery.of(context).padding;
    
    // 使用CompositedTransformFollower将菜单附着在输入框上
    return CompositedTransformFollower(
      link: widget.layerLink,
      targetAnchor: Alignment.topLeft, // 目标锚点（输入框）的左上角
      followerAnchor: Alignment.bottomLeft, // 跟随者（菜单）的底部左侧对齐
      offset: Offset(widget.horizontalOffset, widget.verticalOffset - 16), // 水平和垂直偏移量
      child: ConstrainedBox(
        // 限制菜单最大高度，确保不会超出屏幕
        constraints: BoxConstraints(
          maxHeight: 300, // 最大高度
          maxWidth: widget.menuWidth,
        ),
        child: Material(
          elevation: 8.0,
          borderRadius: BorderRadius.circular(12),
          color: Colors.transparent,
          child: GestureDetector(
            // 阻止点击事件冒泡到外层
            onTap: () {},
            child: Container(
              width: widget.menuWidth,
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