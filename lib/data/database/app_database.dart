import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1)();
  TextColumn get description => text().nullable()();
  TextColumn get imagePaths =>
      text().nullable()(); // JSON array of encrypted file paths
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  // Verification fields
  TextColumn get verificationStatus =>
      text().withDefault(const Constant('none'))(); // none, pending, verified
  TextColumn get verifiedBy => text().nullable()();
  DateTimeColumn get verifiedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Notes])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(notes, notes.verificationStatus);
        await migrator.addColumn(notes, notes.verifiedBy);
        await migrator.addColumn(notes, notes.verifiedAt);
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'notes_app.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
