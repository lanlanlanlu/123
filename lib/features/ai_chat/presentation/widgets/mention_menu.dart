import 'package:flutter/material.dart';
import 'package:record_app/core/widgets/context_menu.dart';
import 'package:record_app/data/database/database.dart';
import 'package:record_app/data/repository/notes_repository.dart';
import 'package:record_app/data/repository/recent_mentions_repository.dart';
import 'package:record_app/data/database/connection/connection.dart' as connection;
import 'package:flutter/foundation.dart';
import 'package:record_app/core/utils/search_service.dart';

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

/// 菜单模式
enum MenuMode {
  main,      // 主菜单模式
  notes,     // 笔记列表模式
  tags,      // 标签列表模式
  locations, // 地点列表模式
}

/// @菜单控制器，用于管理菜单的显示和隐藏
class MentionMenuController {
  OverlayEntry? _overlayEntry;
  bool get isShowing => _overlayEntry != null;
  bool _isClosingAllowed = true;
  
  // 禁止关闭菜单
  void preventClose() {
    _isClosingAllowed = false;
  }
  
  // 允许关闭菜单
  void allowClose() {
    _isClosingAllowed = true;
  }
  
  void hide() {
    if (_overlayEntry != null && _isClosingAllowed) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }
  
  void dispose() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
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
    return Stack(
      children: [
        // 使用ModalBarrier处理点击关闭，而不是GestureDetector
        Positioned.fill(
          child: ModalBarrier(
            color: Colors.transparent,
            dismissible: true,
            onDismiss: () {
              // 只有在允许关闭的情况下才关闭菜单
              controller.hide();
            },
          ),
        ),
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

// 修改_MentionMenuContentState类，添加搜索相关功能
class _MentionMenuContentState extends State<_MentionMenuContent> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  // 当前菜单模式
  MenuMode _currentMode = MenuMode.main;
  
  // 数据库连接
  final AppDatabase _database = connection.connect();
  
  // 笔记数据仓库
  final NotesRepository _notesRepository = NotesRepository();
  
  // 最近提及仓库
  final RecentMentionsRepository _recentMentionsRepository = RecentMentionsRepository();
  
  // 搜索服务
  final SearchService _searchService = SearchService();
  
  // 搜索结果
  List<SearchResultItem> _searchResults = [];
  bool _isSearching = false;
  
  // 笔记列表
  List<Note> _notes = [];
  bool _isLoading = false;
  
  // 最近提及列表
  List<RecentMention> _recentMentions = [];
  bool _isLoadingMentions = false;
  
  // 标签列表
  List<Tag> _tags = [];
  bool _isLoadingTags = false;
  
  // 地点列表
  List<String> _locations = [];
  bool _isLoadingLocations = false;
  
  // 定义菜单高度常量
  static const double itemHeight = 41.0; // 单个条目高度
  static const double dividerHeight = 1.0;
  // 增加1个像素的额外空间来避免溢出
  static const double menuHeight = 5 * itemHeight + 1.0; // 添加1像素余量避免溢出

  // 为搜索框请求焦点的方法
  void requestFocusForSearchField() {
    // 阻止菜单关闭
    widget.controller.preventClose();
    // 请求焦点
    _focusNode.requestFocus();
    // 恢复菜单可关闭状态
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        widget.controller.allowClose();
      }
    });
  }
  
  @override
  void initState() {
    super.initState();
    // 加载最近提及
    _loadRecentMentions();
    
    // 防止搜索框焦点变化导致菜单关闭
    _focusNode.addListener(_handleFocusChange);
    
    // 添加搜索文本变化监听器
    _searchController.addListener(_handleSearchTextChanged);
    
    // 短暂延迟后，如果指定了autofocus为true，则请求焦点
    if (widget.autofocus) {
      Future.delayed(const Duration(milliseconds: 200), () {
        requestFocusForSearchField();
      });
    }
  }
  
  // 处理搜索文本变化
  void _handleSearchTextChanged() {
    final query = _searchController.text.trim();
    
    // 当用户输入搜索文本时，执行搜索
    if (query.isNotEmpty) {
      _performSearch(query);
    } else {
      // 清空搜索结果，恢复主菜单
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }
  
  // 执行搜索操作
  Future<void> _performSearch(String query) async {
    // 设置为正在搜索状态
    setState(() {
      _isSearching = true;
    });
    
    try {
      // 执行搜索
      List<SearchResultItem> results;
      
      // 根据当前模式决定搜索范围
      switch (_currentMode) {
        case MenuMode.notes:
          results = await _searchService.searchNotes(query);
          break;
        case MenuMode.tags:
          results = await _searchService.searchTags(query);
          break;
        case MenuMode.locations:
          results = await _searchService.searchLocations(query);
          break;
        case MenuMode.main:
        default:
          results = await _searchService.searchAll(query);
          break;
      }
      
      // 更新UI，显示搜索结果
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (error) {
      debugPrint('搜索错误: $error');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }
  
  void _handleFocusChange() {
    // 当搜索框获得或失去焦点时
    if (_focusNode.hasFocus) {
      // 搜索框获得焦点时，防止菜单关闭
      widget.controller.preventClose();
      // 短暂延迟后恢复可关闭状态，但此时搜索框已经获取到焦点了
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          widget.controller.allowClose();
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchTextChanged);
    _searchController.dispose();
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  // 加载最近提及记录
  void _loadRecentMentions() {
    setState(() {
      _isLoadingMentions = true;
    });
    
    _recentMentionsRepository.getRecentMentions(limit: 2).then((mentions) {
      if (mounted) {
        setState(() {
          _recentMentions = mentions;
          _isLoadingMentions = false;
        });
      }
    });
  }
  
  // 加载笔记列表
  void _loadNotes() {
    setState(() {
      _isLoading = true;
    });
    
    _notesRepository.getAllNotes().then((notes) {
      if (mounted) {
        setState(() {
          _notes = notes;
          _isLoading = false;
        });
      }
    });
  }
  
  // 加载标签列表
  void _loadTags() {
    setState(() {
      _isLoadingTags = true;
    });
    
    // 使用TagDao的watchAllTags方法获取所有标签，并转换为Future
    _database.tagDao.watchAllTags().first.then((tags) {
      if (mounted) {
        setState(() {
          _tags = tags;
          _isLoadingTags = false;
        });
      }
    }).catchError((error) {
      debugPrint('Error loading tags: $error');
      if (mounted) {
        setState(() {
          _tags = [];
          _isLoadingTags = false;
        });
      }
    });
  }
  
  // 加载地点列表
  void _loadLocations() {
    setState(() {
      _isLoadingLocations = true;
    });
    
    _notesRepository.getAllLocations().then((locations) {
      if (mounted) {
        setState(() {
          _locations = locations;
          _isLoadingLocations = false;
        });
      }
    }).catchError((error) {
      debugPrint('Error loading locations: $error');
      if (mounted) {
        setState(() {
          _locations = [];
          _isLoadingLocations = false;
        });
      }
    });
  }

  // 切换到笔记列表模式
  void _switchToNotesMode() {
    setState(() {
      _currentMode = MenuMode.notes;
      _loadNotes();
    });
  }
  
  // 切换到标签列表模式
  void _switchToTagsMode() {
    setState(() {
      _currentMode = MenuMode.tags;
      _loadTags();
    });
  }
  
  // 切换到地点列表模式
  void _switchToLocationsMode() {
    setState(() {
      _currentMode = MenuMode.locations;
      _loadLocations();
    });
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
                  // 根据搜索状态和当前模式显示不同的内容
                  if (_searchController.text.isNotEmpty) ...[
                    // 搜索结果
                    _buildSearchResultsContent(),
                  ] else if (_currentMode == MenuMode.main) ...[
                    _buildMainMenuContent(),
                  ] else if (_currentMode == MenuMode.notes) ...[
                    _buildNotesListContent(),
                  ] else if (_currentMode == MenuMode.tags) ...[
                    _buildTagsListContent(),
                  ] else if (_currentMode == MenuMode.locations) ...[
                    _buildLocationsListContent(),
                  ],
                  
                  _divider,
                  // 搜索输入框
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: GestureDetector(
                      // 防止点击搜索框时菜单关闭
                      onTap: () {
                        requestFocusForSearchField();
                      },
                      child: AbsorbPointer(
                        absorbing: false,
                        child: TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            hintText: _getSearchHintText(),
                            hintStyle: const TextStyle(fontSize: 14, color: Colors.black38),
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
  
  // 根据当前模式获取搜索框的提示文字
  String _getSearchHintText() {
    switch (_currentMode) {
      case MenuMode.notes:
        return '搜索笔记...';
      case MenuMode.tags:
        return '搜索标签...';
      case MenuMode.locations:
        return '搜索地点...';
      case MenuMode.main:
      default:
        return '添加笔记，地点，标签...';
    }
  }

  // 构建主菜单内容
  Widget _buildMainMenuContent() {
    return Container(
      height: menuHeight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // 最近使用的两项
          if (_isLoadingMentions) ...[
            SizedBox(
              height: 2 * itemHeight, // 两个项目的高度
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            _divider,
          ] else if (_recentMentions.isEmpty) ...[
            _buildNoRecentMentionsView(),
            _divider,
          ] else ...[
            ..._buildRecentMentionsItems(),
            _divider,
          ],
          // 常规选项
          _buildMenuOption(
            icon: Icons.note,
            title: '笔记',
            onTap: () {
              // 切换到笔记列表模式
              _switchToNotesMode();
            },
          ),
          _divider,
          _buildMenuOption(
            icon: Icons.label,
            title: '标签',
            onTap: () {
              // 切换到标签列表模式
              _switchToTagsMode();
            },
          ),
          _divider,
          _buildMenuOption(
            icon: Icons.location_on,
            title: '地点',
            onTap: () {
              // 切换到地点列表模式
              _switchToLocationsMode();
            },
          ),
        ],
      ),
    );
  }

  // 构建无最近提及项目的视图
  Widget _buildNoRecentMentionsView() {
    return SizedBox(
      height: 2 * itemHeight, // 两个项目的高度，不包括多余的分隔线
      child: const Center(
        child: Text(
          '无最近提及项目',
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
      ),
    );
  }
  
  // 构建最近提及项目列表
  List<Widget> _buildRecentMentionsItems() {
    final List<Widget> items = [];
    
    for (int i = 0; i < _recentMentions.length; i++) {
      final mention = _recentMentions[i];
      
      // 根据提及类型设置图标
      IconData icon;
      MentionType mentionType;
      
      switch (mention.type) {
        case 'note':
          icon = Icons.description;
          mentionType = MentionType.note;
          break;
        case 'tag':
          icon = Icons.label;
          mentionType = MentionType.tag;
          break;
        case 'location':
          icon = Icons.location_on;
          mentionType = MentionType.location;
          break;
        default:
          icon = Icons.history;
          mentionType = MentionType.note;
      }
      
      items.add(
        _buildRecentItem(
          icon: icon,
          title: mention.title,
          onTap: () {
            widget.controller.hide();
            widget.onItemSelected(
              MentionItem(
                id: mention.itemId,
                title: mention.title,
                type: mentionType,
              ),
            );
          },
        ),
      );
      
      // 如果不是最后一项，添加分隔线
      if (i < _recentMentions.length - 1) {
        items.add(_divider);
      }
    }
    
    return items;
  }

  // 构建笔记列表内容
  Widget _buildNotesListContent() {
    if (_isLoading) {
      return SizedBox(
        height: menuHeight,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_notes.isEmpty) {
      return SizedBox(
        height: menuHeight,
        child: const Center(child: Text('没有笔记', style: TextStyle(fontSize: 14, color: Colors.black54))),
      );
    }
    
    // 使用menuHeight作为总高度，保持一致性
    return GestureDetector(
      // 监听水平滑动手势
      onHorizontalDragEnd: (DragEndDetails details) {
        // 检测到右滑动作（primaryVelocity > 0）且速度超过阈值
        if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
          // 返回主菜单
          setState(() {
            _currentMode = MenuMode.main;
          });
        }
      },
      child: Container(
        height: menuHeight,
        clipBehavior: Clip.none,
        child: ListView.separated(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: _notes.length,
          separatorBuilder: (_, __) => _divider,
          itemBuilder: (context, index) {
            final note = _notes[index];
            return _buildNoteItem(note);
          },
        ),
      ),
    );
  }

  // 构建单个笔记项
  Widget _buildNoteItem(Note note) {
    // 截取标题，如果太长则显示省略号
    String title = note.title;
    if (title.length > 30) {
      title = '${title.substring(0, 27)}...';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // 先关闭菜单
          widget.controller.hide();
          
          // 然后触发回调
          widget.onItemSelected(
            MentionItem(
              id: note.id.toString(),
              title: note.title,
              type: MentionType.note,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Row(
            children: [
              const Icon(Icons.description, size: 18, color: Colors.black54),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 构建最近使用的项目
  Widget _buildRecentItem({
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
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
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
              const Spacer(),
              const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Colors.black38,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget get _divider => const Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE));

  // 构建标签列表内容
  Widget _buildTagsListContent() {
    if (_isLoadingTags) {
      return SizedBox(
        height: menuHeight,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_tags.isEmpty) {
      return SizedBox(
        height: menuHeight,
        child: const Center(child: Text('没有标签', style: TextStyle(fontSize: 14, color: Colors.black54))),
      );
    }
    
    // 使用右滑返回功能
    return GestureDetector(
      // 监听水平滑动手势
      onHorizontalDragEnd: (DragEndDetails details) {
        // 检测到右滑动作（primaryVelocity > 0）且速度超过阈值
        if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
          // 返回主菜单
          setState(() {
            _currentMode = MenuMode.main;
          });
        }
      },
      child: Container(
        height: menuHeight,
        clipBehavior: Clip.none,
        child: ListView.separated(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: _tags.length,
          separatorBuilder: (_, __) => _divider,
          itemBuilder: (context, index) {
            final tag = _tags[index];
            return _buildTagItem(tag);
          },
        ),
      ),
    );
  }
  
  // 构建单个标签项
  Widget _buildTagItem(Tag tag) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // 先关闭菜单
          widget.controller.hide();
          
          // 然后触发回调
          widget.onItemSelected(
            MentionItem(
              id: tag.name,
              title: tag.name,
              type: MentionType.tag,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Row(
            children: [
              const Icon(Icons.label, size: 18, color: Colors.black54),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tag.name,
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // 构建地点列表内容
  Widget _buildLocationsListContent() {
    if (_isLoadingLocations) {
      return SizedBox(
        height: menuHeight,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_locations.isEmpty) {
      return SizedBox(
        height: menuHeight,
        child: const Center(child: Text('没有地点', style: TextStyle(fontSize: 14, color: Colors.black54))),
      );
    }
    
    // 使用右滑返回功能
    return GestureDetector(
      // 监听水平滑动手势
      onHorizontalDragEnd: (DragEndDetails details) {
        // 检测到右滑动作（primaryVelocity > 0）且速度超过阈值
        if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
          // 返回主菜单
          setState(() {
            _currentMode = MenuMode.main;
          });
        }
      },
      child: Container(
        height: menuHeight,
        clipBehavior: Clip.none,
        child: ListView.separated(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: _locations.length,
          separatorBuilder: (_, __) => _divider,
          itemBuilder: (context, index) {
            final location = _locations[index];
            return _buildLocationItem(location);
          },
        ),
      ),
    );
  }
  
  // 构建单个地点项
  Widget _buildLocationItem(String location) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // 先关闭菜单
          widget.controller.hide();
          
          // 然后触发回调
          widget.onItemSelected(
            MentionItem(
              id: location,
              title: location,
              type: MentionType.location,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Row(
            children: [
              const Icon(Icons.location_on, size: 18, color: Colors.black54),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  location,
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 构建搜索结果内容
  Widget _buildSearchResultsContent() {
    if (_isSearching) {
      return SizedBox(
        height: menuHeight,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_searchResults.isEmpty) {
      return SizedBox(
        height: menuHeight,
        child: const Center(
          child: Text(
            '无搜索结果',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ),
      );
    }

    // 使用ListView显示搜索结果，可上下滚动
    return SizedBox(
      height: menuHeight,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: _searchResults.length,
        separatorBuilder: (_, __) => _divider,
        itemBuilder: (context, index) {
          final result = _searchResults[index];
          return _buildSearchResultItem(result);
        },
      ),
    );
  }

  // 构建单个搜索结果项
  Widget _buildSearchResultItem(SearchResultItem result) {
    // 根据结果类型设置图标
    IconData icon;
    MentionType mentionType;
    
    switch (result.type) {
      case SearchType.note:
        icon = Icons.description;
        mentionType = MentionType.note;
        break;
      case SearchType.tag:
        icon = Icons.label;
        mentionType = MentionType.tag;
        break;
      case SearchType.location:
        icon = Icons.location_on;
        mentionType = MentionType.location;
        break;
      default:
        icon = Icons.search;
        mentionType = MentionType.note;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // 先关闭菜单
          widget.controller.hide();
          
          // 然后触发回调
          widget.onItemSelected(
            MentionItem(
              id: result.id,
              title: result.title,
              type: mentionType,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.black54),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      result.title,
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (result.subtitle != null && result.subtitle!.isNotEmpty)
                      Text(
                        result.subtitle!,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MentionMenuState extends State<MentionMenu> {
  @override
  Widget build(BuildContext context) {
    return Container(); // 这个状态类实际上不会被使用，因为我们使用OverlayEntry
  }
}