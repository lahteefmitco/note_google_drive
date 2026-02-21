import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:note_google_drive/di/injection.dart';
import 'package:note_google_drive/data/repository/note_repository.dart';
import 'package:note_google_drive/services/encryption_service.dart';
import 'package:note_google_drive/services/google_drive_service.dart';
import 'package:note_google_drive/screens/note_form/note_form_screen.dart';
import 'package:note_google_drive/screens/note_detail/note_detail_screen.dart';

import 'cubit/notes_list_cubit.dart';
import 'cubit/notes_list_state.dart';
import 'cubit/sync_cubit.dart';
import 'cubit/sync_state.dart';

class NotesListScreen extends StatelessWidget {
  const NotesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => NotesListCubit(
            noteRepository: getIt<NoteRepository>(),
            encryptionService: getIt<EncryptionService>(),
          )..loadNotes(),
        ),
        BlocProvider(
          create: (_) => SyncCubit(
            googleDriveService: getIt<GoogleDriveService>(),
            noteRepository: getIt<NoteRepository>(),
            encryptionService: getIt<EncryptionService>(),
          ),
        ),
      ],
      child: const _NotesListView(),
    );
  }
}

class _NotesListView extends StatelessWidget {
  const _NotesListView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<SyncCubit, SyncState>(
      listenWhen: (previous, current) =>
          previous.successMessage != current.successMessage ||
          previous.error != current.error,
      listener: (context, syncState) {
        if (syncState.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(syncState.successMessage!),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Reload notes after sync/retrieve
          context.read<NotesListCubit>().loadNotes();
        }
        if (syncState.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(syncState.error!),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        appBar: AppBar(
          title: const Text(
            'My Notes',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              letterSpacing: 0.5,
            ),
          ),
          centerTitle: false,
          backgroundColor: const Color(0xFF16213E),
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            BlocBuilder<SyncCubit, SyncState>(
              buildWhen: (previous, current) =>
                  previous.isLoading != current.isLoading,
              builder: (context, syncState) {
                if (syncState.isLoading) {
                  return const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  );
                }
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.cloud_upload_outlined),
                      tooltip: 'Sync to Google Drive',
                      onPressed: () => context.read<SyncCubit>().syncToCloud(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cloud_download_outlined),
                      tooltip: 'Retrieve from Google Drive',
                      onPressed: () =>
                          context.read<SyncCubit>().retrieveFromCloud(),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        body: BlocBuilder<NotesListCubit, NotesListState>(
          buildWhen: (previous, current) =>
              previous.isLoading != current.isLoading ||
              previous.notes != current.notes ||
              previous.error != current.error,
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF0F3460)),
              );
            }

            if (state.error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.error!,
                      style: TextStyle(color: Colors.red.shade300),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          context.read<NotesListCubit>().loadNotes(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (state.notes.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.note_add_outlined,
                      size: 80,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No notes yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap + to create your first note',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.notes.length,
              itemBuilder: (context, index) {
                final note = state.notes[index];
                final hasImages =
                    note.imagePaths != null && note.imagePaths!.isNotEmpty;
                int imageCount = 0;
                if (hasImages) {
                  try {
                    imageCount = (jsonDecode(note.imagePaths!) as List).length;
                  } catch (_) {}
                }

                return Dismissible(
                  key: Key(note.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF16213E),
                        title: const Text(
                          'Delete Note',
                          style: TextStyle(color: Colors.white),
                        ),
                        content: const Text(
                          'Are you sure you want to delete this note?',
                          style: TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(
                              'Delete',
                              style: TextStyle(color: Colors.red.shade300),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (_) {
                    context.read<NotesListCubit>().deleteNote(
                      note.id,
                      note.imagePaths,
                    );
                  },
                  child: GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NoteDetailScreen(note: note),
                        ),
                      );
                      if (context.mounted) {
                        context.read<NotesListCubit>().loadNotes();
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF0F3460).withValues(alpha: 0.8),
                            const Color(0xFF16213E),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF533483).withValues(alpha: 0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    note.title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (hasImages)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFE94560,
                                      ).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.image_outlined,
                                          size: 14,
                                          color: Color(0xFFE94560),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$imageCount',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFFE94560),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            if (note.description != null &&
                                note.description!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                note.description!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.6),
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 12),
                            Text(
                              DateFormat(
                                'MMM dd, yyyy • hh:mm a',
                              ).format(note.updatedAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NoteFormScreen()),
            );
            if (context.mounted) {
              context.read<NotesListCubit>().loadNotes();
            }
          },
          backgroundColor: const Color(0xFFE94560),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}
