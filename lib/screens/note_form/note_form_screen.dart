import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:note_google_drive/data/database/app_database.dart';
import 'package:note_google_drive/di/injection.dart';
import 'package:note_google_drive/data/repository/note_repository.dart';
import 'package:note_google_drive/services/encryption_service.dart';

import 'cubit/note_form_cubit.dart';
import 'cubit/note_form_state.dart';

class NoteFormScreen extends StatelessWidget {
  final Note? existingNote;

  const NoteFormScreen({super.key, this.existingNote});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = NoteFormCubit(
          noteRepository: getIt<NoteRepository>(),
          encryptionService: getIt<EncryptionService>(),
        );
        if (existingNote != null) {
          cubit.loadExistingImages(existingNote!.imagePaths);
        }
        return cubit;
      },
      child: _NoteFormView(existingNote: existingNote),
    );
  }
}

class _NoteFormView extends StatefulWidget {
  final Note? existingNote;

  const _NoteFormView({this.existingNote});

  @override
  State<_NoteFormView> createState() => _NoteFormViewState();
}

class _NoteFormViewState extends State<_NoteFormView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existingNote?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.existingNote?.description ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingNote != null;

    return BlocListener<NoteFormCubit, NoteFormState>(
      listenWhen: (previous, current) =>
          previous.isSaved != current.isSaved ||
          previous.error != current.error,
      listener: (context, state) {
        if (state.isSaved) {
          Navigator.pop(context, true);
        }
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        appBar: AppBar(
          title: Text(
            isEditing ? 'Edit Note' : 'New Note',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF16213E),
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            BlocBuilder<NoteFormCubit, NoteFormState>(
              buildWhen: (previous, current) =>
                  previous.isLoading != current.isLoading,
              builder: (context, state) {
                return TextButton(
                  onPressed: state.isLoading
                      ? null
                      : () {
                          if (_formKey.currentState!.validate()) {
                            context.read<NoteFormCubit>().saveNote(
                              title: _titleController.text,
                              description: _descriptionController.text,
                              existingId: widget.existingNote?.id,
                            );
                          }
                        },
                  child: state.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(
                            color: Color(0xFFE94560),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                );
              },
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Title Field
              TextFormField(
                controller: _titleController,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Title *',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF16213E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFE94560),
                      width: 1.5,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red.shade400),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Description Field
              TextFormField(
                controller: _descriptionController,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.5,
                ),
                maxLines: 8,
                minLines: 4,
                decoration: InputDecoration(
                  hintText: 'Description (optional)',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 16,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF16213E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFE94560),
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),

              const SizedBox(height: 24),

              // Images Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Images',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  Row(
                    children: [
                      _buildAddImageButton(
                        context,
                        icon: Icons.photo_library_outlined,
                        label: 'Gallery',
                        onTap: () => context.read<NoteFormCubit>().pickImage(),
                      ),
                      const SizedBox(width: 8),
                      _buildAddImageButton(
                        context,
                        icon: Icons.camera_alt_outlined,
                        label: 'Camera',
                        onTap: () =>
                            context.read<NoteFormCubit>().pickImageFromCamera(),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Image Grid
              BlocBuilder<NoteFormCubit, NoteFormState>(
                buildWhen: (previous, current) =>
                    previous.images != current.images,
                builder: (context, state) {
                  if (state.images.isEmpty) {
                    return Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFF16213E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 36,
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No images added',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.3),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: state.images.length,
                    itemBuilder: (context, index) {
                      final image = state.images[index];
                      return _buildImageTile(context, image, index);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddImageButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE94560).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFFE94560).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: const Color(0xFFE94560)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFE94560),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageTile(BuildContext context, NoteImage image, int index) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF16213E),
          ),
          clipBehavior: Clip.antiAlias,
          child: image.isNew && image.bytes != null
              ? Image.memory(
                  image.bytes!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                )
              : FutureBuilder<dynamic>(
                  future: getIt<EncryptionService>().decryptImage(
                    image.encryptedPath!,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      );
                    }
                    return const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFE94560),
                      ),
                    );
                  },
                ),
        ),
        // Remove button
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => context.read<NoteFormCubit>().removeImage(index),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
