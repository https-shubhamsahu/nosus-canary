import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../services/supabase_service.dart';
import '../../../../config/storage_router_config.dart';
import '../storage_router_client.dart';
import '../../domain/models/secure_file_metadata.dart';
import '../../domain/repositories/secure_file_repository.dart';
import '../../../../core/cache/document_cache.dart';
import '../../../../core/utils/debug_logger.dart';

class SupabaseSecureFileRepository implements SecureFileRepository {
  final SupabaseClient _client;

  const SupabaseSecureFileRepository(this._client);

  @override
  Stream<List<SecureFileMetadata>> watchGroupFiles(String groupId) {
    return _client
        .from('secure_files')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .order('uploaded_at', ascending: false)
        .map((rows) => rows.map(_mapFile).toList(growable: false));
  }

  @override
  Stream<List<SecureFileMetadata>> watchAllFiles() {
    return _client
        .from('secure_files')
        .stream(primaryKey: ['id'])
        .order('uploaded_at', ascending: false)
        .map((rows) => rows.map(_mapFile).toList(growable: false));
  }

  @override
  Future<void> uploadFile({
    required String groupId,
    required String name,
    required SecureFileType type,
    required Uint8List rawBytes,
    required String uploaderName,
    required String uploaderInitials,
    required Function(double) onProgress,
  }) async {
    // 1. Emulate upload progress
    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      onProgress(StorageRouterConfig.enableMultiCloudStorage ? i / 20.0 : i / 10.0);
    }

    final tempFileId = 'file_${DateTime.now().millisecondsSinceEpoch}';
    final storedName = _displayNameFor(name, type);
    final storedType = type.name == 'note' ? 'markdown' : type.name;

    if (StorageRouterConfig.enableMultiCloudStorage) {
      try {
        await StorageRouterClient.instance.upload(
          fileId: tempFileId,
          groupId: groupId,
          name: storedName,
          type: storedType,
          bytes: rawBytes,
          contentType: _contentTypeFor(type),
        );
        onProgress(1.0);

        await SupabaseService.instance.logEvent(
          'file_uploaded',
          groupId: groupId,
          fileId: tempFileId,
          metadata: {
            'file_name': name,
            'size_bytes': rawBytes.length,
            'storage_backend': 'storage-router',
          },
        );
        return;
      } catch (e, s) {
        debugLog(
          'Storage router upload failed; falling back to Supabase Storage: $e\n$s',
        );
      }
    }

    // 2. Upload raw binary bytes to Supabase Storage. cacheControl: '0'
    // means browsers/CDN never cache this response — the signed URL that
    // resolves to these bytes already expires in minutes, but a cached
    // response would keep serving cached bytes from local disk even after
    // that signed URL is no longer valid for new requests.
    await _client.storage.from('secure-files').uploadBinary(
          tempFileId,
          rawBytes,
          fileOptions: const FileOptions(cacheControl: '0'),
        );

    // 3. Insert metadata row in secure_files table
    await _client.from('secure_files').insert({
      'id': tempFileId,
      'group_id': groupId,
      'name': storedName,
      'type': storedType,
      'size_bytes': rawBytes.length,
      'is_watermarked': true,
      'is_pinned': false,
      'security_status': 'secured',
    });

    // 4. Log event
    await SupabaseService.instance.logEvent(
      'file_uploaded',
      groupId: groupId,
      fileId: tempFileId,
      metadata: {
        'file_name': name,
        'size_bytes': rawBytes.length,
      },
    );
  }

  @override
  Future<void> deleteFile(String groupId, String fileId) async {
    DocumentCache.instance.evict(fileId);
    // 1. Delete object from Google Drive (if linked) or Supabase Storage
    final isGoogleDrive = !fileId.startsWith('file_') &&
        !fileId.startsWith('sec_gen_') &&
        !fileId.startsWith('file_gen_');
    if (isGoogleDrive) {
      try {
        await SupabaseService.instance.deleteGDriveFile(fileId);
      } catch (_) {}
    } else {
      if (StorageRouterConfig.enableMultiCloudStorage) {
        try {
          await StorageRouterClient.instance.delete(fileId);
        } catch (e) {
          debugLog('Storage router delete skipped/fell back: $e');
        }
      }
      try {
        await _client.storage.from('secure-files').remove([fileId]);
      } catch (_) {}
    }

    // 2. Delete database metadata
    await _client.from('secure_files').delete().eq('id', fileId);

    // 3. Log event
    await SupabaseService.instance.logEvent(
      'file_deleted',
      groupId: groupId,
      fileId: fileId,
      metadata: {
        'file_id': fileId,
      },
    );
  }

  @override
  Future<void> togglePin(String groupId, String fileId) async {
    final response = await _client
        .from('secure_files')
        .select('is_pinned')
        .eq('id', fileId)
        .maybeSingle();

    if (response != null) {
      final currentPin = response['is_pinned'] as bool? ?? false;
      await _client
          .from('secure_files')
          .update({'is_pinned': !currentPin})
          .eq('id', fileId);
    }
  }

  @override
  Future<void> addGoogleDriveLink({
    required String groupId,
    required String name,
    required SecureFileType type,
    required String driveUrl,
    required String uploaderName,
    required String uploaderInitials,
  }) async {
    final gDriveId = _extractGoogleDriveFileId(driveUrl);
    if (gDriveId == null || gDriveId.isEmpty) {
      throw Exception("Invalid Google Drive URL. Could not parse file ID.");
    }

    await _client.from('secure_files').insert({
      'id': gDriveId,
      'group_id': groupId,
      'name': name,
      'type': type.name == 'note' ? 'markdown' : type.name,
      'size_bytes': 0,
      'is_watermarked': true,
      'is_pinned': false,
      'security_status': 'secured',
    });

    await SupabaseService.instance.logEvent(
      'file_uploaded',
      groupId: groupId,
      fileId: gDriveId,
      metadata: {
        'file_name': name,
        'gdrive_file_id': gDriveId,
      },
    );
  }

  @override
  Future<String?> getServiceAccountEmail() async {
    return await SupabaseService.instance.getServiceAccountEmail();
  }

  @override
  Future<Uint8List?> downloadFile({
    required String fileId,
    required Function(double) onProgress,
  }) async {
    // Session cache first — re-opening a recently viewed document is instant
    // and costs no network.
    final cached = DocumentCache.instance.get(fileId);
    if (cached != null) {
      onProgress(1.0);
      return cached;
    }
    try {
      onProgress(0.1);
      final isGoogleDrive = !fileId.startsWith('file_') && !fileId.startsWith('sec_gen_');
      if (isGoogleDrive) {
        onProgress(0.3);
        final gDriveBytes = await SupabaseService.instance.downloadGDriveFile(fileId);
        onProgress(1.0);
        if (gDriveBytes != null) DocumentCache.instance.put(fileId, gDriveBytes);
        return gDriveBytes;
      } else {
        if (StorageRouterConfig.enableMultiCloudStorage) {
          try {
            onProgress(0.3);
            final bytes = await StorageRouterClient.instance.download(fileId);
            onProgress(1.0);
            DocumentCache.instance.put(fileId, bytes);
            return bytes;
          } catch (e) {
            debugLog('Storage router download fell back to Supabase Storage: $e');
          }
        }
        onProgress(0.3);
        final bytes = await _client.storage.from('secure-files').download(fileId);
        onProgress(1.0);
        DocumentCache.instance.put(fileId, bytes);
        return bytes;
      }
    } catch (e, s) {
      debugLog("SupabaseSecureFileRepository: downloadFile error: $e\n$s");
      return null;
    }
  }

  SecureFileMetadata _mapFile(Map<String, dynamic> row) {
    return SecureFileMetadata(
      id: row['id'] as String,
      groupId: row['group_id'] as String,
      name: row['name'] as String,
      type: _parseType(row['type']),
      sizeBytes: row['size_bytes'] as int? ?? 0,
      uploaderName: row['uploaded_by'] as String? ?? 'Unknown',
      uploadedAt:
          DateTime.tryParse(row['uploaded_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      isWatermarked: row['is_watermarked'] as bool? ?? true,
      isPinned: row['is_pinned'] as bool? ?? false,
      status: _parseStatus(row['security_status']),
    );
  }

  SecureFileType _parseType(Object? value) {
    final normalized = value?.toString().toLowerCase();
    if (normalized == 'markdown') return SecureFileType.note;
    return SecureFileType.values.firstWhere(
      (type) => type.name == normalized,
      orElse: () => SecureFileType.pdf,
    );
  }

  SecureFileStatus _parseStatus(Object? value) {
    return SecureFileStatus.values.firstWhere(
      (status) => status.name == value?.toString().toLowerCase(),
      orElse: () => SecureFileStatus.pending,
    );
  }

  String? _extractGoogleDriveFileId(String url) {
    final RegExp regExp1 = RegExp(r'/file/d/([a-zA-Z0-9-_]+)');
    final RegExp regExp2 = RegExp(r'[?&]id=([a-zA-Z0-9-_]+)');

    final match1 = regExp1.firstMatch(url);
    if (match1 != null && match1.groupCount >= 1) {
      return match1.group(1);
    }

    final match2 = regExp2.firstMatch(url);
    if (match2 != null && match2.groupCount >= 1) {
      return match2.group(1);
    }

    if (!url.contains('/') && url.length > 10) {
      return url;
    }

    return null;
  }

  String _displayNameFor(String name, SecureFileType type) {
    final extension = switch (type) {
      SecureFileType.note => '.md',
      SecureFileType.pdf => '.pdf',
      SecureFileType.image => '.png',
      SecureFileType.scan => '.jpg',
    };
    return name.replaceAll(extension, '');
  }

  String _contentTypeFor(SecureFileType type) {
    return switch (type) {
      SecureFileType.note => 'text/markdown',
      SecureFileType.pdf => 'application/pdf',
      SecureFileType.image => 'image/png',
      SecureFileType.scan => 'image/jpeg',
    };
  }

  @override
  Future<void> renameFile(String fileId, String newName) async {
    final fileRow = await _client
        .from('secure_files')
        .select('group_id')
        .eq('id', fileId)
        .maybeSingle();
    final groupId = fileRow?['group_id'] as String?;

    await _client.from('secure_files').update({
      'name': newName,
    }).eq('id', fileId);

    if (groupId != null) {
      await SupabaseService.instance.logEvent(
        'file_renamed',
        groupId: groupId,
        fileId: fileId,
        metadata: {
          'new_name': newName,
        },
      );
    }
  }

  @override
  Future<List<SecureFileMetadata>> getAllFiles() async {
    final response = await _client
        .from('secure_files')
        .select()
        .order('uploaded_at', ascending: false);
    return (response as List)
        .map((row) => _mapFile(row as Map<String, dynamic>))
        .toList();
  }
}
