import 'dart:developer';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:note_google_drive/data/repository/note_repository.dart';
import 'package:note_google_drive/services/encryption_service.dart';
import 'package:note_google_drive/services/google_drive_service.dart';

import 'sync_state.dart';

class SyncCubit extends Cubit<SyncState> {
  final GoogleDriveService _googleDriveService;
  final NoteRepository _noteRepository;
  final EncryptionService _encryptionService;

  SyncCubit({
    required GoogleDriveService googleDriveService,
    required NoteRepository noteRepository,
    required EncryptionService encryptionService,
  }) : _googleDriveService = googleDriveService,
       _noteRepository = noteRepository,
       _encryptionService = encryptionService,
       super(const SyncState());

  Future<void> syncToCloud() async {
    emit(const SyncState(isLoading: true));

    try {
      // Sign in if not already
      if (!_googleDriveService.isSignedIn) {
        final signedIn = await _googleDriveService.signIn();
        if (!signedIn) {
          emit(const SyncState(error: 'Google Sign-In failed or cancelled'));
          return;
        }
      }

      final notes = await _noteRepository.getAllNotes();
      if (notes.isEmpty) {
        emit(const SyncState(successMessage: 'No notes to sync'));
        return;
      }

      await _googleDriveService.syncToGoogleDrive(
        notes: notes,
        encryptionService: _encryptionService,
      );

      emit(
        SyncState(
          successMessage: '${notes.length} note(s) synced to Google Drive',
        ),
      );
    } catch (e) {
      log("Error=> $e");
      emit(SyncState(error: 'Sync failed: $e'));
    }
  }

  Future<void> retrieveFromCloud() async {
    emit(const SyncState(isLoading: true));

    try {
      // Sign in if not already
      if (!_googleDriveService.isSignedIn) {
        final signedIn = await _googleDriveService.signIn();
        if (!signedIn) {
          emit(const SyncState(error: 'Google Sign-In failed or cancelled'));
          return;
        }
      }

      final importedCount = await _googleDriveService.retrieveFromGoogleDrive(
        noteRepository: _noteRepository,
        encryptionService: _encryptionService,
      );

      emit(
        SyncState(
          successMessage: importedCount > 0
              ? '$importedCount note(s) retrieved from Google Drive'
              : 'No new notes to retrieve',
        ),
      );
    } catch (e) {
      emit(SyncState(error: 'Retrieve failed: $e'));
    }
  }
}
