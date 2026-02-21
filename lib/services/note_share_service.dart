import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:note_google_drive/data/database/app_database.dart';
import 'package:note_google_drive/data/repository/note_repository.dart';
import 'package:note_google_drive/services/encryption_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

class NoteShareService {
  /// Export a note as a .notefile (JSON with base64-encoded images)
  /// and share via Android Share Sheet.
  Future<void> shareNoteForVerification({
    required Note note,
    required EncryptionService encryptionService,
    required NoteRepository noteRepository,
  }) async {
    try {
      // Build note data
      final noteData = <String, dynamic>{
        'id': note.id,
        'title': note.title,
        'description': note.description,
        'createdAt': note.createdAt.toIso8601String(),
        'updatedAt': note.updatedAt.toIso8601String(),
        'images': <String>[],
      };

      // Convert images to base64
      if (note.imagePaths != null && note.imagePaths!.isNotEmpty) {
        final paths = List<String>.from(jsonDecode(note.imagePaths!));
        final base64Images = <String>[];

        for (final path in paths) {
          final file = File(path);
          if (await file.exists()) {
            // Read encrypted bytes, decrypt, then base64 encode for sharing
            final decryptedBytes = await encryptionService.decryptImage(path);
            base64Images.add(base64Encode(decryptedBytes));
          }
        }
        noteData['images'] = base64Images;
      }

      // Write to temp .notefile
      final tempDir = await getTemporaryDirectory();
      final noteFile = File(p.join(tempDir.path, '${note.id}.notefile'));
      await noteFile.writeAsString(jsonEncode(noteData));

      // Update local verification status to "pending"
      await noteRepository.updateVerificationStatus(
        noteId: note.id,
        status: 'pending',
      );

      // Share via share sheet
      await Share.shareXFiles([
        XFile(noteFile.path),
      ], text: 'Please verify this note: ${note.title}');

      log('NoteShareService: Shared note ${note.id} for verification');
    } catch (e) {
      log('NoteShareService: Error sharing note => $e');
      rethrow;
    }
  }

  /// Create a .noteverified response file and share it back.
  Future<void> createAndShareVerificationResponse({
    required String noteId,
    required String noteTitle,
    required String verifierName,
  }) async {
    try {
      final responseData = {
        'noteId': noteId,
        'noteTitle': noteTitle,
        'verifiedBy': verifierName,
        'verifiedAt': DateTime.now().toIso8601String(),
        'status': 'verified',
      };

      // Write to temp .noteverified file
      final tempDir = await getTemporaryDirectory();
      final responseFile = File(p.join(tempDir.path, '$noteId.noteverified'));
      await responseFile.writeAsString(jsonEncode(responseData));

      // Share via share sheet
      await Share.shareXFiles([
        XFile(responseFile.path),
      ], text: 'Verification response for: $noteTitle');

      log('NoteShareService: Shared verification response for $noteId');
    } catch (e) {
      log('NoteShareService: Error creating verification response => $e');
      rethrow;
    }
  }

  /// Parse a .notefile and return the note data as a Map.
  Future<Map<String, dynamic>> parseNoteFile(String filePath) async {
    final file = File(filePath);
    final content = await file.readAsString();
    return jsonDecode(content) as Map<String, dynamic>;
  }

  /// Parse a .noteverified file and return verification data.
  Future<Map<String, dynamic>> parseVerificationResponse(
    String filePath,
  ) async {
    final file = File(filePath);
    final content = await file.readAsString();
    return jsonDecode(content) as Map<String, dynamic>;
  }

  /// Decode base64 images from a parsed .notefile into Uint8List list.
  List<Uint8List> decodeBase64Images(Map<String, dynamic> noteData) {
    final images = noteData['images'] as List<dynamic>? ?? [];
    return images.map((b64) => base64Decode(b64 as String)).toList();
  }

  /// Import a verification response and update the local note.
  Future<bool> importVerificationResponse({
    required String filePath,
    required NoteRepository noteRepository,
  }) async {
    try {
      final data = await parseVerificationResponse(filePath);
      final noteId = data['noteId'] as String;
      final verifiedBy = data['verifiedBy'] as String;
      final verifiedAt = DateTime.parse(data['verifiedAt'] as String);

      // Check if the note exists locally
      final exists = await noteRepository.noteExists(noteId);
      if (!exists) {
        log('NoteShareService: Note $noteId not found locally');
        return false;
      }

      await noteRepository.updateVerificationStatus(
        noteId: noteId,
        status: 'verified',
        verifiedBy: verifiedBy,
        verifiedAt: verifiedAt,
      );

      log('NoteShareService: Note $noteId verified by $verifiedBy');
      return true;
    } catch (e) {
      log('NoteShareService: Error importing verification => $e');
      return false;
    }
  }
}
