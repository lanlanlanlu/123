import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:record_app/data/database/database.dart';
import 'package:record_app/data/repository/index.dart';
import 'package:record_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:record_app/features/home/presentation/bloc/home_event.dart';
import 'package:record_app/features/home/presentation/bloc/home_state.dart';
import 'package:record_app/features/home/presentation/widgets/note_card.dart';
import 'package:record_app/features/home/presentation/widgets/empty_notes_view.dart';

/// 特定位置的笔记列表页面
class LocationNotesPage extends StatelessWidget {
  final String location;
  
  const LocationNotesPage({
    super.key,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final notesRepository = context.read<NotesRepository>();
        return HomeBloc(notesRepository: notesRepository)
          ..add(HomeLoadNotesByLocation(location));
      },
      child: _LocationNotesView(location: location),
    );
  }
}

class _LocationNotesView extends StatelessWidget {
  final String location;
  
  const _LocationNotesView({required this.location});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(location),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocConsumer<HomeBloc, HomeState>(
        listener: (context, state) {
          if (state is HomeOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is HomeLoadFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          if (state is HomeLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is HomeLoadSuccess) {
            if (state.notes.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.location_off,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '此位置没有笔记',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('返回'),
                    ),
                  ],
                ),
              );
            }
            
            return ListView.builder(
              itemCount: state.notes.length,
              itemBuilder: (context, index) => NoteCard(
                note: state.notes[index],
                onDelete: (noteId) => context.read<HomeBloc>().add(HomeNoteDeleted(noteId)),
                onRestore: (noteId) => context.read<HomeBloc>().add(HomeNoteRestored(noteId)),
              ),
            );
          } else if (state is HomeLoadFailure) {
            return Center(child: Text('加载失败: ${state.message}'));
          }
          
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
} 