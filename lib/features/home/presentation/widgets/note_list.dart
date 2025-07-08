import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record_app/data/database/database.dart';
import 'package:record_app/features/home/presentation/widgets/note_card.dart';
import 'package:record_app/features/home/presentation/widgets/empty_notes_view.dart';

/// 笔记列表组件，用于显示所有笔记
class NoteList extends StatelessWidget {
  /// 可选的笔记列表参数
  final List<Note>? notes;
  
  /// 可选的笔记操作回调
  final Function(Note)? onNoteTogglePin;
  
  /// 可选的笔记删除回调
  final Function(Note)? onNoteDelete;

  /// 构造函数 - 可以通过传入notes直接显示，或者通过database自动加载
  const NoteList({
    super.key, 
    this.notes,
    this.onNoteTogglePin,
    this.onNoteDelete,
  });

  @override
  Widget build(BuildContext context) {
    // 如果提供了notes参数，则直接使用
    if (notes != null) {
      if (notes!.isEmpty) {
        return const EmptyNotesView();
      }
      
      return ListView.builder(
        itemCount: notes!.length,
        itemBuilder: (context, index) => NoteCard(
          note: notes![index],
          onDelete: onNoteDelete != null ? (_) => onNoteDelete!(notes![index]) : null,
        ),
      );
    }
    
    // 否则从database加载
    final database = Provider.of<AppDatabase>(context);

    return StreamBuilder<List<Note>>(
      stream: database.noteDao.watchAllNotes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('出错了: ${snapshot.error}'));
        }
        
        if (snapshot.hasData) {
          final notes = snapshot.data!;
          
          if (notes.isEmpty) {
            return const EmptyNotesView();
          }
          
          return ListView.builder(
            itemCount: notes.length,
            itemBuilder: (context, index) => NoteCard(
              note: notes[index],
              onDelete: onNoteDelete != null ? (_) => onNoteDelete!(notes[index]) : null,
            ),
          );
        }
        
        return const Center(child: Text('未知状态'));
      },
    );
  }
} 