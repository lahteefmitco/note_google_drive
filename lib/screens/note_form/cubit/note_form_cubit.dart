import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:note_google_drive/data/database/app_database.dart';
import 'package:note_google_drive/data/repository/note_repository.dart';
import 'package:note_google_drive/services/encryption_service.dart';
import 'package:uuid/uuid.dart';

import 'note_form_state.dart';

class NoteFormCubit extends Cubit<NoteFormState> {
  final NoteRepository _noteRepository;
  final EncryptionService _encryptionService;
  final ImagePicker _imagePicker = ImagePicker();

  NoteFormCubit({
    required NoteRepository noteRepository,
    required EncryptionService encryptionService,
  }) : _noteRepository = noteRepository,
       _encryptionService = encryptionService,
       super(const NoteFormState());

  /// Load existing images when editing a note
  void loadExistingImages(String? imagePathsJson) {
    if (imagePathsJson == null || imagePathsJson.isEmpty) return;
    try {
      final paths = List<String>.from(jsonDecode(imagePathsJson));
      final images = paths.map((p) => NoteImage(encryptedPath: p)).toList();
      emit(state.copyWith(images: images));
    } catch (_) {}
  }

  Future<void> pickImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      final bytes = await File(pickedFile.path).readAsBytes();
      final newImage = NoteImage(
        bytes: bytes,
        originalFileName: pickedFile.name,
      );

      emit(state.copyWith(images: [...state.images, newImage]));
    } catch (e) {
      log("Error on pickImage=> $e");
      emit(state.copyWith(error: 'Failed to pick image: $e'));
    }
  }

  Future<void> pickImageFromCamera() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      final bytes = await File(pickedFile.path).readAsBytes();
      final newImage = NoteImage(
        bytes: bytes,
        originalFileName: pickedFile.name,
      );

      emit(state.copyWith(images: [...state.images, newImage]));
    } catch (e) {
      log("Error on pickImageFromCamera=> $e");
      emit(state.copyWith(error: 'Failed to capture image: $e'));
    }
  }

  void removeImage(int index) {
    final updatedImages = List<NoteImage>.from(state.images);
    updatedImages.removeAt(index);
    emit(state.copyWith(images: updatedImages));
  }

  Future<void> saveNote({
    required String title,
    String? description,
    String? existingId,
  }) async {
    if (title.trim().isEmpty) {
      emit(state.copyWith(error: 'Title is required'));
      return;
    }

    emit(state.copyWith(isLoading: true));

    try {
      final List<String> encryptedPaths = [];

      for (final image in state.images) {
        if (image.isExisting) {
          // Keep existing encrypted paths
          encryptedPaths.add(image.encryptedPath!);
        } else if (image.isNew && image.bytes != null) {
          // Encrypt and save new images
          final fileName =
              '${const Uuid().v4()}_${image.originalFileName ?? 'image'}';
          final path = await _encryptionService.encryptAndSaveImage(
            image.bytes!,
            fileName,
          );
          encryptedPaths.add(path);
        }
      }

      final now = DateTime.now();
      final noteId = existingId ?? const Uuid().v4();

      final noteCompanion = NotesCompanion(
        id: Value(noteId),
        title: Value(title.trim()),
        description: Value(
          description?.trim().isNotEmpty == true ? description!.trim() : null,
        ),
        imagePaths: Value(
          encryptedPaths.isNotEmpty ? jsonEncode(encryptedPaths) : null,
        ),
        createdAt: existingId != null ? const Value.absent() : Value(now),
        updatedAt: Value(now),
      );

      if (existingId != null) {
        await _noteRepository.updateNote(noteCompanion);
      } else {
        await _noteRepository.insertNote(noteCompanion);
      }

      emit(state.copyWith(isLoading: false, isSaved: true));
    } catch (e) {
      log("Error on saveNote=> $e");
      emit(state.copyWith(isLoading: false, error: 'Failed to save: $e'));
    }
  }
}
