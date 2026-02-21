import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:note_google_drive/di/injection.dart';
import 'package:note_google_drive/data/repository/note_repository.dart';
import 'package:note_google_drive/services/note_share_service.dart';
import 'package:note_google_drive/screens/notes_list/notes_list_screen.dart';
import 'package:note_google_drive/screens/verify_note/verify_note_screen.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  setupDependencies();
  runApp(const NotesApp());
}

class NotesApp extends StatefulWidget {
  const NotesApp({super.key});

  @override
  State<NotesApp> createState() => _NotesAppState();
}

class _NotesAppState extends State<NotesApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();

    // Handle shared files when app is opened from a shared intent
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (files.isNotEmpty) {
        _handleSharedFiles(files);
      }
    });

    // Handle shared files when app is already running
    ReceiveSharingIntent.instance.getMediaStream().listen((files) {
      if (files.isNotEmpty) {
        _handleSharedFiles(files);
      }
    });
  }

  Future<void> _handleSharedFiles(List<SharedMediaFile> files) async {
    for (final file in files) {
      final filePath = file.path;
      log('NotesApp: Received shared file: $filePath');

      if (filePath.endsWith('.notefile')) {
        await _handleNoteFile(filePath);
      } else if (filePath.endsWith('.noteverified')) {
        await _handleVerificationResponse(filePath);
      }
    }
    // Reset sharing intent after handling
    ReceiveSharingIntent.instance.reset();
  }

  Future<void> _handleNoteFile(String filePath) async {
    try {
      final shareService = getIt<NoteShareService>();
      final noteData = await shareService.parseNoteFile(filePath);

      // Navigate to verification screen
      _navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => VerifyNoteScreen(noteData: noteData)),
      );
    } catch (e) {
      log('NotesApp: Error parsing .notefile => $e');
      _showSnackBar('Failed to open note file', isError: true);
    }
  }

  Future<void> _handleVerificationResponse(String filePath) async {
    try {
      final shareService = getIt<NoteShareService>();
      final noteRepo = getIt<NoteRepository>();

      final success = await shareService.importVerificationResponse(
        filePath: filePath,
        noteRepository: noteRepo,
      );

      if (success) {
        _showSnackBar('Note verified successfully! ✅');
      } else {
        _showSnackBar(
          'Note not found locally. Make sure the note exists.',
          isError: true,
        );
      }
    } catch (e) {
      log('NotesApp: Error importing verification => $e');
      _showSnackBar('Failed to import verification', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    final context = _navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? Colors.red.shade700
              : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFFE94560),
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF16213E),
          foregroundColor: Colors.white,
        ),
      ),
      home: const NotesListScreen(),
    );
  }
}
