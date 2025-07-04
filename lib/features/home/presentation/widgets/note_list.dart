import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/data/database/database.dart';
import 'package:record/features/home/presentation/widgets/note_card.dart';
import 'package:record/features/home/presentation/widgets/empty_notes_view.dart';

/// 笔记列表组件，用于显示所有笔记
class NoteList extends StatelessWidget {
  const NoteList({super.key});

  @override
  Widget build(BuildContext context) {
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
            itemBuilder: (context, index) => NoteCard(note: notes[index]),
          );
        }
        
        return const Center(child: Text('未知状态'));
      },
    );
  }
} 