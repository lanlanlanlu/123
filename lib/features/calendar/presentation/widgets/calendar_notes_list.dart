import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../bloc/calendar_state.dart';
import '../../../home/presentation/widgets/note_list.dart';

class CalendarNotesList extends StatelessWidget {
  final CalendarState state;
  
  const CalendarNotesList({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: SelectableText.rich(
          TextSpan(
            text: '${s.aiChatError}: ${state.error}',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (state.selectedDateNotes.isEmpty) {
      return const CalendarEmptyNotesView();
    }

    return NoteList(
      notes: state.selectedDateNotes,
      onNoteTogglePin: (note) {
        // TODO: 实现置顶功能
      },
      onNoteDelete: (note) {
        // TODO: 实现删除功能
      },
    );
  }
}

class CalendarEmptyNotesView extends StatelessWidget {
  const CalendarEmptyNotesView({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            s.calendarNoNotesOnDate(''),
            style: const TextStyle(
              fontSize: 24,
              color: Colors.grey,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }
}