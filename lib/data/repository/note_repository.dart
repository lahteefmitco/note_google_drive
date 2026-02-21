import 'package:drift/drift.dart';
import 'package:note_google_drive/data/database/app_database.dart';

class NoteRepository {
  final AppDatabase _db;

  NoteRepository(this._db);

  Future<List<Note>> getAllNotes() {
    return (_db.select(_db.notes)..orderBy([
          (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
        ]))
        .get();
  }

  Future<Note?> getNoteById(String id) {
    return (_db.select(
      _db.notes,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> insertNote(NotesCompanion note) {
    return _db.into(_db.notes).insert(note);
  }

  Future<void> updateNote(NotesCompanion note) {
    return (_db.update(
      _db.notes,
    )..where((t) => t.id.equals(note.id.value))).write(note);
  }

  Future<void> deleteNote(String id) {
    return (_db.delete(_db.notes)..where((t) => t.id.equals(id))).go();
  }

  Future<bool> noteExists(String id) async {
    final note = await getNoteById(id);
    return note != null;
  }

  Future<void> upsertNote(NotesCompanion note) async {
    final exists = await noteExists(note.id.value);
    if (exists) {
      await updateNote(note);
    } else {
      await insertNote(note);
    }
  }
}
