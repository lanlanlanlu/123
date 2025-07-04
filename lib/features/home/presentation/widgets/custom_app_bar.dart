import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:record/features/home/presentation/bloc/app_bar_bloc.dart';

/// 自定义应用栏
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AppBarBloc(),
      child: const _CustomAppBarContent(),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}

class _CustomAppBarContent extends StatelessWidget {
  const _CustomAppBarContent();

  @override
  Widget build(BuildContext context) {
    // 获取屏幕宽度，用于响应式布局
    final screenWidth = MediaQuery.of(context).size.width;
    // 根据屏幕宽度决定图标尺寸和间距
    final iconSize = screenWidth < 600 ? 22.0 : 24.0;
    final iconSpacing = screenWidth < 600 ? 12.0 : 20.0;
    
    return BlocBuilder<AppBarBloc, AppBarState>(
      builder: (context, state) {
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth < 600 ? 16.0 : 24.0, 
            vertical: 8.0
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
          child: SafeArea(
            child: Row(
              children: [
                // 左侧标题 - 使用更细的字体
                Text(
                  '笔记',
                  style: TextStyle(
                    fontSize: screenWidth < 600 ? 28 : 32,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const Spacer(),
                // 右侧图标组 - 使用响应式布局
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 位置图标
                    _buildIconButton(
                      icon: Icons.location_on_outlined,
                      size: iconSize,
                      onPressed: () => context.read<AppBarBloc>().add(AppBarLocationPressed(context)),
                    ),
                    SizedBox(width: iconSpacing),
                    // 标签图标 - 使用与其他图标一致的处理方式
                    _buildIconButton(
                      icon: Icons.tag,
                      size: iconSize,
                      onPressed: () => context.read<AppBarBloc>().add(AppBarTagPressed()),
                    ),
                    SizedBox(width: iconSpacing),
                    // 搜索图标
                    _buildIconButton(
                      icon: Icons.search,
                      size: iconSize,
                      onPressed: () => context.read<AppBarBloc>().add(AppBarSearchPressed()),
                    ),
                    SizedBox(width: iconSpacing),
                    // 菜单图标
                    _buildIconButton(
                      icon: Icons.menu,
                      size: iconSize,
                      onPressed: () => context.read<AppBarBloc>().add(AppBarMenuPressed()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // 辅助方法：构建图标按钮，所有按钮使用相同的构建方法
  Widget _buildIconButton({
    required IconData icon,
    required double size,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(
        icon,
        size: size,
      ),
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(),
      onPressed: onPressed,
    );
  }
} 