import 'dart:typed_data';

class NoteFormState {
  final bool isLoading;
  final bool isSaved;
  final String? error;
  final List<NoteImage> images;

  const NoteFormState({
    this.isLoading = false,
    this.isSaved = false,
    this.error,
    this.images = const [],
  });

  NoteFormState copyWith({
    bool? isLoading,
    bool? isSaved,
    String? error,
    List<NoteImage>? images,
  }) {
    return NoteFormState(
      isLoading: isLoading ?? this.isLoading,
      isSaved: isSaved ?? this.isSaved,
      error: error,
      images: images ?? this.images,
    );
  }
}

/// Represents an image in the note form.
/// Can be an existing encrypted image (with path) or a newly picked image (with bytes).
class NoteImage {
  final String? encryptedPath; // For existing images
  final Uint8List? bytes; // For newly picked images
  final String? originalFileName;

  const NoteImage({this.encryptedPath, this.bytes, this.originalFileName});

  bool get isNew => bytes != null;
  bool get isExisting => encryptedPath != null;
}
