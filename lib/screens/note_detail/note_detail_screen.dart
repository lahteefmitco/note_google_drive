import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:note_google_drive/data/database/app_database.dart';
import 'package:note_google_drive/di/injection.dart';
import 'package:note_google_drive/data/repository/note_repository.dart';
import 'package:note_google_drive/services/encryption_service.dart';
import 'package:note_google_drive/services/note_share_service.dart';
import 'package:note_google_drive/screens/note_form/note_form_screen.dart';

class NoteDetailScreen extends StatefulWidget {
  final Note note;

  const NoteDetailScreen({super.key, required this.note});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  late Note _note;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _note = widget.note;
  }

  Future<void> _refreshNote() async {
    final updated = await getIt<NoteRepository>().getNoteById(_note.id);
    if (updated != null && mounted) {
      setState(() => _note = updated);
    }
  }

  List<String> _getImagePaths() {
    if (_note.imagePaths == null || _note.imagePaths!.isEmpty) return [];
    try {
      return List<String>.from(jsonDecode(_note.imagePaths!));
    } catch (_) {
      return [];
    }
  }

  Future<void> _shareForVerification() async {
    setState(() => _isSharing = true);
    try {
      await getIt<NoteShareService>().shareNoteForVerification(
        note: _note,
        encryptionService: getIt<EncryptionService>(),
        noteRepository: getIt<NoteRepository>(),
      );
      await _refreshNote();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Note shared for verification'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Widget _buildVerificationBadge() {
    final status = _note.verificationStatus;

    if (status == 'verified') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified, color: Color(0xFF4CAF50), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Verified',
                    style: TextStyle(
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (_note.verifiedBy != null)
                    Text(
                      'By ${_note.verifiedBy}${_note.verifiedAt != null ? ' on ${DateFormat('MMM dd, yyyy').format(_note.verifiedAt!)}' : ''}',
                      style: TextStyle(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (status == 'pending') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.schedule, color: Colors.orange, size: 20),
            SizedBox(width: 8),
            Text(
              'Verification Pending',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final imagePaths = _getImagePaths();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text(
          'Note Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Share for verification button
          IconButton(
            icon: _isSharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.share_outlined),
            tooltip: 'Share for Verification',
            onPressed: _isSharing ? null : _shareForVerification,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NoteFormScreen(existingNote: _note),
                ),
              );
              await _refreshNote();
            },
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
            tooltip: 'Delete',
            onPressed: () async {
              final confirm = await showDialog<bool>(
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

              if (confirm == true && context.mounted) {
                // Delete images
                final encService = getIt<EncryptionService>();
                for (final path in imagePaths) {
                  await encService.deleteEncryptedImage(path);
                }
                await getIt<NoteRepository>().deleteNote(_note.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Verification badge
            _buildVerificationBadge(),
            if (_note.verificationStatus != 'none') const SizedBox(height: 16),

            // Title
            Text(
              _note.title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 8),

            // Date
            Text(
              'Created: ${DateFormat('MMM dd, yyyy • hh:mm a').format(_note.createdAt)}\n'
              'Updated: ${DateFormat('MMM dd, yyyy • hh:mm a').format(_note.updatedAt)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.35),
                height: 1.5,
              ),
            ),

            if (_note.description != null && _note.description!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _note.description!,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.8),
                    height: 1.6,
                  ),
                ),
              ),
            ],

            if (imagePaths.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Images (${imagePaths.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: imagePaths.length,
                itemBuilder: (context, index) {
                  return _DecryptedImageWidget(
                    encryptedPath: imagePaths[index],
                    onTap: () => _showFullImage(context, imagePaths[index]),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context, String encryptedPath) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Center(
              child: FutureBuilder<Uint8List>(
                future: getIt<EncryptionService>().decryptImage(encryptedPath),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return InteractiveViewer(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(snapshot.data!),
                      ),
                    );
                  }
                  return const CircularProgressIndicator(
                    color: Color(0xFFE94560),
                  );
                },
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecryptedImageWidget extends StatefulWidget {
  final String encryptedPath;
  final VoidCallback onTap;

  const _DecryptedImageWidget({
    required this.encryptedPath,
    required this.onTap,
  });

  @override
  State<_DecryptedImageWidget> createState() => _DecryptedImageWidgetState();
}

class _DecryptedImageWidgetState extends State<_DecryptedImageWidget> {
  Uint8List? _imageBytes;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await getIt<EncryptionService>().decryptImage(
        widget.encryptedPath,
      );
      if (mounted) {
        setState(() {
          _imageBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF16213E),
        ),
        clipBehavior: Clip.antiAlias,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFE94560),
                ),
              )
            : _error != null
            ? Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white.withValues(alpha: 0.3),
                  size: 36,
                ),
              )
            : Image.memory(
                _imageBytes!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
      ),
    );
  }
}
