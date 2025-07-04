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
    return BlocBuilder<AppBarBloc, AppBarState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            // 移除了底部细线
          ),
          child: SafeArea(
            child: Row(
              children: [
                // 左侧标题 - 使用更细的字体
                const Text(
                  '笔记',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w400, // 更细的字体
                  ),
                ),
                const Spacer(),
                // 右侧图标组 - 放在一个Row中以增加视觉凝聚力
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 位置图标
                    IconButton(
                      icon: const Icon(
                        Icons.location_on_outlined,
                        size: 22, // 更小的图标
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        context.read<AppBarBloc>().add(AppBarLocationPressed());
                      },
                    ),
                    const SizedBox(width: 8), // 减少图标间距
                    // 标签图标
                    IconButton(
                      icon: const Text(
                        "#",
                        style: TextStyle(
                          fontSize: 22, // 更小的图标
                          fontWeight: FontWeight.w500, // 适当调整粗细
                        ),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        context.read<AppBarBloc>().add(AppBarTagPressed());
                      },
                    ),
                    const SizedBox(width: 8), // 减少图标间距
                    // 搜索图标
                    IconButton(
                      icon: const Icon(
                        Icons.search,
                        size: 22, // 更小的图标
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        context.read<AppBarBloc>().add(AppBarSearchPressed());
                      },
                    ),
                    const SizedBox(width: 8), // 减少图标间距
                    // 菜单图标
                    IconButton(
                      icon: const Icon(
                        Icons.menu,
                        size: 22, // 更小的图标
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        context.read<AppBarBloc>().add(AppBarMenuPressed());
                      },
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
} 