import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../groups/models/group_file.dart';
import 'secure_file_providers.dart';
import '../../domain/models/secure_file_metadata.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/providers/profile_provider.dart';
import '../../../../services/supabase_service.dart';
import '../../../notes/providers/notes_provider.dart';

enum UploadStage { idle, picking, processing, complete, error }

class UploadState {
  final UploadStage stage;
  final double progress; // 0.0–1.0
  final String? fileName;
  final String? errorMessage;

  const UploadState({
    this.stage = UploadStage.idle,
    this.progress = 0.0,
    this.fileName,
    this.errorMessage,
  });

  UploadState copyWith({
    UploadStage? stage,
    double? progress,
    String? fileName,
    String? errorMessage,
  }) => UploadState(
    stage: stage ?? this.stage,
    progress: progress ?? this.progress,
    fileName: fileName ?? this.fileName,
    errorMessage: errorMessage ?? this.errorMessage,
  );
}

class UploadNotifier extends Notifier<UploadState> {
  bool _isCancelled = false;

  @override
  UploadState build() => const UploadState();

  void cancelUpload() {
    _isCancelled = true;
    state = const UploadState(stage: UploadStage.idle);
  }

  void reset() {
    _isCancelled = false;
    state = const UploadState();
  }

  Future<void> uploadDocument(
    String fileName,
    FileType type,
    String groupId,
    Uint8List rawBytes,
  ) async {
    _isCancelled = false;
    state = state.copyWith(
      stage: UploadStage.processing,
      fileName: fileName,
      progress: 0,
    );

    try {
      final repo = ref.read(secureFileRepositoryProvider);
      final domainType = SecureFileType.values.firstWhere(
        (e) => e.name == type.name,
        orElse: () => SecureFileType.pdf,
      );

      final currentUser = ref.read(authRepositoryProvider).currentUser;
      final profileVal = ref.read(profileProvider).value;
      final uploaderName = profileVal?.displayName ?? currentUser?.email ?? 'Anonymous';
      String uploaderInitials = 'AN';
      if (uploaderName.isNotEmpty) {
        if (uploaderName.contains('@')) {
          final prefix = uploaderName.split('@').first;
          uploaderInitials = prefix.substring(0, prefix.length >= 2 ? 2 : prefix.length).toUpperCase();
        } else {
          uploaderInitials = uploaderName.substring(0, uploaderName.length >= 2 ? 2 : uploaderName.length).toUpperCase();
        }
      }

      await repo.uploadFile(
        groupId: groupId,
        name: fileName,
        type: domainType,
        rawBytes: rawBytes,
        uploaderName: uploaderName,
        uploaderInitials: uploaderInitials,
        onProgress: (prog) {
          if (_isCancelled) {
            throw Exception('Upload cancelled');
          }
          state = state.copyWith(progress: prog);
        },
      );

      if (_isCancelled) return;

      state = state.copyWith(stage: UploadStage.complete, progress: 1.0);

      // Auto-reset after confirmation display
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!_isCancelled) {
        state = const UploadState();
      }
    } catch (e) {
      if (_isCancelled) {
        state = const UploadState(stage: UploadStage.idle);
        return;
      }
      state = state.copyWith(
        stage: UploadStage.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> linkGoogleDriveDocument(
    String fileName,
    String groupId,
    String driveUrl,
  ) async {
    _isCancelled = false;
    state = state.copyWith(
      stage: UploadStage.processing,
      fileName: fileName,
      progress: 0,
    );

    try {
      final repo = ref.read(secureFileRepositoryProvider);
      final currentUser = ref.read(authRepositoryProvider).currentUser;
      final profileVal = ref.read(profileProvider).value;
      final uploaderName = profileVal?.displayName ?? currentUser?.email ?? 'Anonymous';
      String uploaderInitials = 'AN';
      if (uploaderName.isNotEmpty) {
        if (uploaderName.contains('@')) {
          final prefix = uploaderName.split('@').first;
          uploaderInitials = prefix.substring(0, prefix.length >= 2 ? 2 : prefix.length).toUpperCase();
        } else {
          uploaderInitials = uploaderName.substring(0, uploaderName.length >= 2 ? 2 : uploaderName.length).toUpperCase();
        }
      }

      // Simulate some progress for linking
      for (int i = 1; i <= 5; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (_isCancelled) {
          throw Exception('Linking cancelled');
        }
        state = state.copyWith(progress: i / 5.0);
      }

      await repo.addGoogleDriveLink(
        groupId: groupId,
        name: fileName,
        type: SecureFileType.pdf,
        driveUrl: driveUrl,
        uploaderName: uploaderName,
        uploaderInitials: uploaderInitials,
      );

      if (_isCancelled) return;

      state = state.copyWith(stage: UploadStage.complete, progress: 1.0);

      // Auto-reset after confirmation display
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!_isCancelled) {
        state = const UploadState();
      }
    } catch (e) {
      if (_isCancelled) {
        state = const UploadState(stage: UploadStage.idle);
        return;
      }
      state = state.copyWith(
        stage: UploadStage.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> savePrivateNote({
    required String userId,
    required String content,
  }) async {
    _isCancelled = false;
    state = state.copyWith(
      stage: UploadStage.processing,
      fileName: 'Private Notepad',
      progress: 0,
    );

    try {
      // Simulate save progress
      for (int i = 1; i <= 5; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (_isCancelled) {
          throw Exception('Save cancelled');
        }
        state = state.copyWith(progress: i / 5.0);
      }

      await SupabaseService.instance.saveUserNote(userId, content);

      if (_isCancelled) return;

      state = state.copyWith(stage: UploadStage.complete, progress: 1.0);

      // Reload notepad to display the newly imported note immediately
      ref.read(userNoteProvider.notifier).loadNote(userId);

      // Auto-reset after confirmation display
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!_isCancelled) {
        state = const UploadState();
      }
    } catch (e) {
      if (_isCancelled) {
        state = const UploadState(stage: UploadStage.idle);
        return;
      }
      state = state.copyWith(
        stage: UploadStage.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Compatibility wrapper for UI to trigger simulated secure uploads with raw bytes.
  Future<void> simulateUpload(
    String fileName,
    FileType type,
    String groupId,
  ) async {
    final docTitle = fileName.replaceAll(type.extension, '');
    final docText = _generateMockDocumentText(docTitle, type);
    final docBytes = Uint8List.fromList(utf8.encode(docText));
    await uploadDocument(fileName, type, groupId, docBytes);
  }

  String _generateMockDocumentText(String title, FileType type) {
    return '''$title / Study Document
This document contains shared study notes for $title.

Section 1: Overview
The notes in this document are shared securely via the group workspace. Access is managed through group membership and Supabase Row Level Security.

Section 2: Guidelines
1. Watermarks are displayed to deter unauthorized sharing.
2. Touch the screen to reveal content when blur is enabled.
3. All document access is logged to the audit trail.

Section 3: Next Steps
Review the notes and collaborate with your study group. All activity is tracked in the group audit log.''';
  }
}

final uploadProvider = NotifierProvider<UploadNotifier, UploadState>(
  UploadNotifier.new,
);
