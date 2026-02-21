import 'dart:io';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class EncryptionService {
  // 32-byte key for AES-256
  static const String _keyString = 'NotesApp2024SecureKey123456789!!';
  // 16-byte IV
  static const String _ivString = 'NotesAppIV123456';

  late final enc.Key _key;
  late final enc.IV _iv;
  late final enc.Encrypter _encrypter;

  EncryptionService() {
    _key = enc.Key.fromUtf8(_keyString);
    _iv = enc.IV.fromUtf8(_ivString);
    _encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));
  }

  /// Encrypts image bytes and saves to app documents directory.
  /// Returns the absolute file path of the encrypted file.
  Future<String> encryptAndSaveImage(
    Uint8List imageBytes,
    String fileName,
  ) async {
    final appDir = await getApplicationDocumentsDirectory();
    final encryptedDir = Directory(p.join(appDir.path, 'encrypted_images'));
    if (!await encryptedDir.exists()) {
      await encryptedDir.create(recursive: true);
    }

    final encrypted = _encrypter.encryptBytes(imageBytes, iv: _iv);
    final filePath = p.join(encryptedDir.path, '$fileName.enc');
    final file = File(filePath);
    await file.writeAsBytes(encrypted.bytes);

    return filePath;
  }

  /// Decrypts an encrypted image file and returns the raw bytes.
  Future<Uint8List> decryptImage(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Encrypted file not found', filePath);
    }

    final encryptedBytes = await file.readAsBytes();
    final encrypted = enc.Encrypted(encryptedBytes);
    final decryptedBytes = _encrypter.decryptBytes(encrypted, iv: _iv);

    return Uint8List.fromList(decryptedBytes);
  }

  /// Deletes an encrypted image file.
  Future<void> deleteEncryptedImage(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Encrypts raw bytes and returns encrypted bytes (for Drive upload).
  Uint8List encryptBytes(Uint8List data) {
    final encrypted = _encrypter.encryptBytes(data, iv: _iv);
    return Uint8List.fromList(encrypted.bytes);
  }

  /// Decrypts raw bytes (for Drive download).
  Uint8List decryptBytes(Uint8List encryptedData) {
    final encrypted = enc.Encrypted(encryptedData);
    final decrypted = _encrypter.decryptBytes(encrypted, iv: _iv);
    return Uint8List.fromList(decrypted);
  }
}
