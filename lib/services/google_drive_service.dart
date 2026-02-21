import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:note_google_drive/data/database/app_database.dart';
import 'package:note_google_drive/data/repository/note_repository.dart';
import 'package:note_google_drive/services/encryption_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class GoogleDriveService {
  static const String _appFolderName = 'NotesAppData';

  /// The Web OAuth Client ID from Google Cloud Console.
  /// Required on Android for google_sign_in 7.x to exchange tokens.
  static const String _serverClientId ="113187967910-p6dsqjskgh64qb7377tjghpujn6ramll.apps.googleusercontent.com";
     // 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _initialized = false;
  drive.DriveApi? _driveApi;

  bool get isSignedIn => _driveApi != null;

  Future<bool> signIn() async {
    try {
      if (!_initialized) {
        log('GoogleDriveService: Initializing GoogleSignIn...');
        await _googleSignIn.initialize(serverClientId: _serverClientId);
        _initialized = true;
        log('GoogleDriveService: Initialized successfully');
      }

      // Authenticate
      log('GoogleDriveService: Starting authenticate...');
      await _googleSignIn.authenticate();
      log('GoogleDriveService: Authenticated successfully');

      // Authorize with Drive scope
      log('GoogleDriveService: Requesting Drive scope authorization...');
      final authorizationResult = await _googleSignIn.authorizationClient
          .authorizeScopes([drive.DriveApi.driveFileScope]);
      log('GoogleDriveService: Authorization granted');

      final accessToken = authorizationResult.accessToken;
      log(
        'GoogleDriveService: Got access token: ${accessToken != null ? "yes" : "null"}',
      );

      final headers = {'Authorization': 'Bearer $accessToken'};

      final client = GoogleAuthClient(headers);
      _driveApi = drive.DriveApi(client);
      return true;
    } catch (e, stackTrace) {
      log('GoogleDriveService: Sign-in FAILED => $e');
      log('GoogleDriveService: StackTrace => $stackTrace');
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.disconnect();
    _driveApi = null;
  }

  Future<String> _getOrCreateAppFolder() async {
    final driveApi = _driveApi!;

    // Search for existing folder
    final folderList = await driveApi.files.list(
      q: "name = '$_appFolderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
      spaces: 'drive',
    );

    if (folderList.files != null && folderList.files!.isNotEmpty) {
      return folderList.files!.first.id!;
    }

    // Create new folder
    final folder = drive.File()
      ..name = _appFolderName
      ..mimeType = 'application/vnd.google-apps.folder';

    final createdFolder = await driveApi.files.create(folder);
    return createdFolder.id!;
  }

  /// Syncs all local notes to Google Drive.
  /// Uses note UUID as filename to avoid duplication.
  Future<void> syncToGoogleDrive({
    required List<Note> notes,
    required EncryptionService encryptionService,
  }) async {
    if (_driveApi == null) throw Exception('Not signed in');

    final folderId = await _getOrCreateAppFolder();

    for (final note in notes) {
      // Prepare note metadata as JSON
      final noteData = {
        'id': note.id,
        'title': note.title,
        'description': note.description,
        'createdAt': note.createdAt.toIso8601String(),
        'updatedAt': note.updatedAt.toIso8601String(),
        'images': <String>[],
      };

      // Upload images
      final List<String> imageFileIds = [];
      if (note.imagePaths != null && note.imagePaths!.isNotEmpty) {
        final paths = List<String>.from(jsonDecode(note.imagePaths!));
        for (int i = 0; i < paths.length; i++) {
          final imagePath = paths[i];
          final file = File(imagePath);
          if (await file.exists()) {
            final encryptedBytes = await file.readAsBytes();
            final imageFileName = '${note.id}_image_$i.enc';

            final existingImageId = await _findFileInFolder(
              folderId,
              imageFileName,
            );

            final driveFile = drive.File()
              ..name = imageFileName
              ..parents = existingImageId == null ? [folderId] : null;

            final media = drive.Media(
              Stream.value(encryptedBytes),
              encryptedBytes.length,
            );

            if (existingImageId != null) {
              await _driveApi!.files.update(
                driveFile,
                existingImageId,
                uploadMedia: media,
              );
              imageFileIds.add(existingImageId);
            } else {
              final uploaded = await _driveApi!.files.create(
                driveFile,
                uploadMedia: media,
              );
              imageFileIds.add(uploaded.id!);
            }
          }
        }
      }

      noteData['images'] = imageFileIds;

      // Upload note metadata JSON
      final noteFileName = '${note.id}.json';
      final noteJson = jsonEncode(noteData);
      final noteBytes = utf8.encode(noteJson);

      final existingNoteId = await _findFileInFolder(folderId, noteFileName);

      final driveFile = drive.File()
        ..name = noteFileName
        ..parents = existingNoteId == null ? [folderId] : null;

      final media = drive.Media(Stream.value(noteBytes), noteBytes.length);

      if (existingNoteId != null) {
        await _driveApi!.files.update(
          driveFile,
          existingNoteId,
          uploadMedia: media,
        );
      } else {
        await _driveApi!.files.create(driveFile, uploadMedia: media);
      }
    }
  }

  /// Retrieves notes from Google Drive that don't exist locally.
  Future<int> retrieveFromGoogleDrive({
    required NoteRepository noteRepository,
    required EncryptionService encryptionService,
  }) async {
    if (_driveApi == null) throw Exception('Not signed in');

    final folderId = await _getOrCreateAppFolder();
    int importedCount = 0;

    // List all JSON files in the app folder
    final fileList = await _driveApi!.files.list(
      q: "'$folderId' in parents and name contains '.json' and trashed = false",
      spaces: 'drive',
    );

    if (fileList.files == null) return 0;

    for (final file in fileList.files!) {
      try {
        // Download the JSON metadata
        final response =
            await _driveApi!.files.get(
                  file.id!,
                  downloadOptions: drive.DownloadOptions.fullMedia,
                )
                as drive.Media;

        final bytes = <int>[];
        await for (final chunk in response.stream) {
          bytes.addAll(chunk);
        }

        final jsonData = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        final noteId = jsonData['id'] as String;

        // Check if note already exists locally (deduplication)
        if (await noteRepository.noteExists(noteId)) {
          continue;
        }

        // Download associated encrypted images
        final List<String> localImagePaths = [];
        final imageIds = jsonData['images'] as List<dynamic>? ?? [];

        for (final imageId in imageIds) {
          try {
            final imageResponse =
                await _driveApi!.files.get(
                      imageId as String,
                      downloadOptions: drive.DownloadOptions.fullMedia,
                    )
                    as drive.Media;

            final imageBytes = <int>[];
            await for (final chunk in imageResponse.stream) {
              imageBytes.addAll(chunk);
            }

            // Save encrypted bytes directly to local storage
            final appDir = await getApplicationDocumentsDirectory();
            final encryptedDir = Directory(
              p.join(appDir.path, 'encrypted_images'),
            );
            if (!await encryptedDir.exists()) {
              await encryptedDir.create(recursive: true);
            }

            final localFileName =
                '${noteId}_image_${imageIds.indexOf(imageId)}.enc';
            final localPath = p.join(encryptedDir.path, localFileName);
            await File(localPath).writeAsBytes(imageBytes);
            localImagePaths.add(localPath);
          } catch (e) {
            // Skip failed image downloads
          }
        }

        // Insert note into local DB
        final noteCompanion = NotesCompanion(
          id: Value(noteId),
          title: Value(jsonData['title'] as String),
          description: Value(jsonData['description'] as String?),
          imagePaths: Value(
            localImagePaths.isNotEmpty ? jsonEncode(localImagePaths) : null,
          ),
          createdAt: Value(DateTime.parse(jsonData['createdAt'] as String)),
          updatedAt: Value(DateTime.parse(jsonData['updatedAt'] as String)),
        );

        await noteRepository.insertNote(noteCompanion);
        importedCount++;
      } catch (e) {
        // Skip failed note downloads
      }
    }

    return importedCount;
  }

  /// Find a file by name within a folder. Returns file ID or null.
  Future<String?> _findFileInFolder(String folderId, String fileName) async {
    final result = await _driveApi!.files.list(
      q: "'$folderId' in parents and name = '$fileName' and trashed = false",
      spaces: 'drive',
    );

    if (result.files != null && result.files!.isNotEmpty) {
      return result.files!.first.id!;
    }
    return null;
  }
}
