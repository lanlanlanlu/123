import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/data/database/database.dart';
import 'package:record/features/tags/presentation/pages/tag_detail_page.dart';

/// 笔记标签组件，用于显示单个笔记的所有标签
class NoteTagsWidget extends StatelessWidget {
  /// 笔记ID
  final int noteId;
  
  const NoteTagsWidget({
    super.key, 
    required this.noteId
  });

  @override
  Widget build(BuildContext context) {
    final database = Provider.of<AppDatabase>(context, listen: false);

    return StreamBuilder<List<Tag>>(
      stream: database.noteDao.watchTagsForNote(noteId),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final tags = snapshot.data!;
          return Wrap(
            alignment: WrapAlignment.start,
            spacing: 6.0,
            runSpacing: 4.0,
            children: tags.map((tag) => InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TagDetailPage(tagName: tag.name),
                  ),
                );
              },
              child: Text(
                '#${tag.name}',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            )).toList(),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
} 