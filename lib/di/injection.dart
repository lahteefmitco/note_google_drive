import 'package:get_it/get_it.dart';
import 'package:note_google_drive/data/database/app_database.dart';
import 'package:note_google_drive/data/repository/note_repository.dart';
import 'package:note_google_drive/services/encryption_service.dart';
import 'package:note_google_drive/services/google_drive_service.dart';

final getIt = GetIt.instance;

void setupDependencies() {
  // Database
  getIt.registerLazySingleton<AppDatabase>(() => AppDatabase());

  // Repository
  getIt.registerLazySingleton<NoteRepository>(
    () => NoteRepository(getIt<AppDatabase>()),
  );

  // Services
  getIt.registerLazySingleton<EncryptionService>(() => EncryptionService());
  getIt.registerLazySingleton<GoogleDriveService>(() => GoogleDriveService());
}
