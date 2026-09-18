import 'dart:typed_data';
import '../models/secure_file_metadata.dart';

abstract interface class SecureFileRepository {
  Stream<List<SecureFileMetadata>> watchGroupFiles(String groupId);

  Stream<List<SecureFileMetadata>> watchAllFiles();

  Future<void> uploadFile({
    required String groupId,
    required String name,
    required SecureFileType type,
    required Uint8List rawBytes,
    required String uploaderName,
    required String uploaderInitials,
    required Function(double) onProgress,
  });

  Future<void> deleteFile(String groupId, String fileId);

  Future<void> togglePin(String groupId, String fileId);

  Future<void> addGoogleDriveLink({
    required String groupId,
    required String name,
    required SecureFileType type,
    required String driveUrl,
    required String uploaderName,
    required String uploaderInitials,
  });

  Future<String?> getServiceAccountEmail();

  Future<Uint8List?> downloadFile({
    required String fileId,
    required Function(double) onProgress,
  });

  Future<void> renameFile(String fileId, String newName);

  Future<List<SecureFileMetadata>> getAllFiles();
}
