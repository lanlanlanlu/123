import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:record/features/home/presentation/bloc/location_list_bloc.dart';
import 'package:record/features/home/presentation/pages/location_notes_page.dart';

/// 位置信息列表页面
class LocationListPage extends StatelessWidget {
  const LocationListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LocationListBloc()..add(LocationListLoaded()),
      child: const LocationListView(),
    );
  }
}

class LocationListView extends StatefulWidget {
  const LocationListView({super.key});

  @override
  State<LocationListView> createState() => _LocationListViewState();
}

class _LocationListViewState extends State<LocationListView> {
  // 用于跟踪是否有位置被删除
  bool _hasLocationDeleted = false;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('位置信息'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(_hasLocationDeleted), // 返回时传递是否有位置被删除
        ),
      ),
      body: BlocConsumer<LocationListBloc, LocationListState>(
        listener: (context, state) {
          // 当位置列表加载成功，并且是由于删除位置触发的，设置标志位
          if (state is LocationListLoadedState && state.isAfterDeletion) {
            setState(() {
              _hasLocationDeleted = true; // 标记有位置被删除
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('位置已删除')),
            );
          }
        },
        builder: (context, state) {
          if (state is LocationListLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is LocationListLoadedState) {
            return _buildLocationList(context, state.locations);
          } else if (state is LocationListError) {
            return Center(child: Text('加载失败: ${state.message}'));
          }
          
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
  
  Widget _buildLocationList(BuildContext context, List<String> locations) {
    if (locations.isEmpty) {
      return const Center(child: Text('没有位置信息'));
    }
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Wrap(
        spacing: 12.0,
        runSpacing: 12.0,
        children: locations.map((location) => _buildLocationChip(context, location)).toList(),
      ),
    );
  }
  
  Widget _buildLocationChip(BuildContext context, String location) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? const Color(0xFFF0F0F0)
            : Colors.grey[800],
        borderRadius: BorderRadius.circular(32),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LocationNotesPage(location: location),
            ),
          );
        },
        borderRadius: BorderRadius.circular(32),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7, // 限制最大宽度为屏幕宽度的70%
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: Colors.deepPurple,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    location,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _showDeleteConfirmationDialog(context, location),
                  child: const Icon(
                    Icons.close,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Future<void> _showDeleteConfirmationDialog(BuildContext context, String location) async {
    // 在显示对话框前先获取bloc
    final locationListBloc = context.read<LocationListBloc>();
    
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '温馨提示',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20.0),
                Text(
                  '确定要删除 $location 位置信息?',
                  style: const TextStyle(fontSize: 16.0),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                        ),
                        child: const Text(
                          '取消',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16.0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16.0),
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          // 使用预先获取的bloc而不是从对话框context中读取
                          locationListBloc.add(LocationDeleted(location));
                          Navigator.of(dialogContext).pop();
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                        ),
                        child: const Text(
                          '确定',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.0,
                          ),
                        ),
                      ),
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