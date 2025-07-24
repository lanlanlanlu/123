import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:record_app/core/utils/search_service.dart';
import 'package:record_app/data/database/database.dart';
import 'package:record_app/features/home/presentation/bloc/search_bloc.dart';
import 'package:record_app/features/home/presentation/bloc/search_event.dart';
import 'package:record_app/features/home/presentation/bloc/search_state.dart';
import 'package:record_app/data/repository/notes_repository.dart';
import 'package:record_app/features/tags/presentation/pages/tag_detail_page.dart';
import 'package:record_app/features/home/presentation/pages/location_notes_page.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 不再创建新的SearchBloc，使用全局提供的实例
    return const _SearchPageContent();
  }
}

class _SearchPageContent extends StatefulWidget {
  const _SearchPageContent();

  @override
  State<_SearchPageContent> createState() => _SearchPageContentState();
}

class _SearchPageContentState extends State<_SearchPageContent> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // 自动获取焦点，打开键盘
    Future.delayed(Duration.zero, () {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: const InputDecoration(
            hintText: '搜索笔记、标签、地点...',
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          style: const TextStyle(fontSize: 16),
          onChanged: (query) {
            context.read<SearchBloc>().add(SearchQueryChanged(query));
          },
          textInputAction: TextInputAction.search,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _controller.clear();
                context.read<SearchBloc>().add(const SearchCleared());
              },
            ),
        ],
      ),
      body: BlocConsumer<SearchBloc, SearchState>(
        listener: (context, state) {
          // 如果有选中的结果，导航到对应的页面
          if (state.selectedResult != null) {
            _navigateToResult(context, state.selectedResult!);
          }
        },
        builder: (context, state) {
          switch (state.status) {
            case SearchStatus.initial:
              return const _InitialView();
            case SearchStatus.loading:
              return const _LoadingView();
            case SearchStatus.success:
              return _ResultsView(results: state.results);
            case SearchStatus.empty:
              return const _EmptyView();
            case SearchStatus.error:
              return _ErrorView(message: state.errorMessage ?? '未知错误');
          }
        },
      ),
    );
  }

  // 根据结果类型导航到不同页面
  void _navigateToResult(BuildContext context, SearchResultItem result) async {
    final bloc = context.read<SearchBloc>();
    
    switch (result.type) {
      case SearchType.note:
        // 获取笔记对象
        final noteId = int.tryParse(result.id);
        if (noteId != null) {
          final notesRepository = NotesRepository();
          final note = await notesRepository.getNoteById(noteId);
          if (note != null) {
            if (context.mounted) {
              // 使用extra传递笔记对象
              context.go('/note/${note.id}', extra: note);
            }
          }
        }
        break;
      case SearchType.tag:
        // 导航到标签详情页，复用已有的TagDetailPage
        if (context.mounted) {
          // 使用Navigator.push直接打开标签详情页
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => TagDetailPage(tagName: result.title),
            ),
          );
        }
        break;
      case SearchType.location:
        // 导航到地点笔记列表，复用已有的LocationNotesPage
        if (context.mounted) {
          // 使用Navigator.push直接打开地点笔记列表页
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => LocationNotesPage(location: result.title),
            ),
          );
        }
        break;
      case SearchType.all:
        // 这种情况不应该出现在结果中
        break;
    }
    
    // 清除选中状态，以便用户可以再次选择同一结果
    bloc.add(const SearchCleared());
  }
}

// 初始状态视图
class _InitialView extends StatelessWidget {
  const _InitialView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            '输入关键词搜索',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

// 加载中视图
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}

// 搜索结果视图
class _ResultsView extends StatelessWidget {
  final List<SearchResultItem> results;

  const _ResultsView({required this.results});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final result = results[index];
        return _ResultListTile(result: result);
      },
    );
  }
}

// 搜索结果列表项
class _ResultListTile extends StatelessWidget {
  final SearchResultItem result;

  const _ResultListTile({required this.result});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String typeText;
    
    // 根据结果类型设置图标和类型文本
    switch (result.type) {
      case SearchType.note:
        icon = Icons.note;
        typeText = '笔记';
        break;
      case SearchType.tag:
        icon = Icons.label;
        typeText = '标签';
        break;
      case SearchType.location:
        icon = Icons.location_on;
        typeText = '地点';
        break;
      case SearchType.all:
      default:
        icon = Icons.search;
        typeText = '其他';
    }
    
    return ListTile(
      leading: Icon(icon),
      title: Text(result.title),
      subtitle: result.subtitle != null && result.subtitle!.isNotEmpty
          ? Text(
              result.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : Text(typeText),
      onTap: () {
        context.read<SearchBloc>().add(SearchResultSelected(result));
      },
    );
  }
}

// 空结果视图
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            '未找到匹配结果',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

// 错误视图
class _ErrorView extends StatelessWidget {
  final String message;

  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            '搜索出错',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 