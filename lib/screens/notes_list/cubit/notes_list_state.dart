import 'package:note_google_drive/data/database/app_database.dart';

class NotesListState {
  final bool isLoading;
  final List<Note> notes;
  final String? error;

  const NotesListState({
    this.isLoading = false,
    this.notes = const [],
    this.error,
  });

  NotesListState copyWith({bool? isLoading, List<Note>? notes, String? error}) {
    return NotesListState(
      isLoading: isLoading ?? this.isLoading,
      notes: notes ?? this.notes,
      error: error,
    );
  }
}
