import 'dart:developer';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:note_google_drive/data/repository/note_repository.dart';
import 'package:note_google_drive/services/encryption_service.dart';
import 'dart:convert';

import 'notes_list_state.dart';

class NotesListCubit extends Cubit<NotesListState> {
  final NoteRepository _noteRepository;
  final EncryptionService _encryptionService;

  NotesListCubit({
    required NoteRepository noteRepository,
    required EncryptionService encryptionService,
  }) : _noteRepository = noteRepository,
       _encryptionService = encryptionService,
       super(const NotesListState());

  Future<void> loadNotes() async {
    emit(state.copyWith(isLoading: true));
    try {
      final notes = await _noteRepository.getAllNotes();
      emit(state.copyWith(isLoading: false, notes: notes));
    } catch (e) {
      log("Error=> $e");
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> deleteNote(String id, String? imagePaths) async {
    try {
      // Delete associated encrypted images
      if (imagePaths != null && imagePaths.isNotEmpty) {
        final paths = List<String>.from(jsonDecode(imagePaths));
        for (final path in paths) {
          await _encryptionService.deleteEncryptedImage(path);
        }
      }
      await _noteRepository.deleteNote(id);
      await loadNotes();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
