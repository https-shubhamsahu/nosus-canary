import 'package:flutter/foundation.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────

enum FileType { pdf, image, markdown, scan }

extension FileTypeExt on FileType {
  String get label {
    switch (this) {
      case FileType.pdf:
        return 'PDF';
      case FileType.image:
        return 'IMAGE';
      case FileType.markdown:
        return 'NOTE';
      case FileType.scan:
        return 'SCAN';
    }
  }

  String get extension {
    switch (this) {
      case FileType.pdf:
        return '.pdf';
      case FileType.image:
        return '.png';
      case FileType.markdown:
        return '.md';
      case FileType.scan:
        return '.jpg';
    }
  }
}

enum FileSecurityStatus { secured, processing, pending }

// ─── GroupFile ────────────────────────────────────────────────────────────────

@immutable
class GroupFile {
  final String id;
  final String name;
  final FileType type;
  final String groupId;
  final String uploadedBy;
  final String ownerId;
  final DateTime uploadedAt;
  final int sizeBytes;
  final bool isWatermarked;
  final bool isPinned;
  final FileSecurityStatus securityStatus;

  const GroupFile({
    required this.id,
    required this.name,
    required this.type,
    required this.groupId,
    required this.uploadedBy,
    required this.ownerId,
    required this.uploadedAt,
    required this.sizeBytes,
    this.isWatermarked = true,
    this.isPinned = false,
    this.securityStatus = FileSecurityStatus.secured,
  });

  String get sizeLabel {
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get uploadedAtLabel {
    final diff = DateTime.now().difference(uploadedAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${uploadedAt.day}/${uploadedAt.month}/${uploadedAt.year}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupFile &&
          id == other.id &&
          name == other.name &&
          type == other.type &&
          groupId == other.groupId &&
          uploadedBy == other.uploadedBy &&
          ownerId == other.ownerId &&
          uploadedAt == other.uploadedAt &&
          sizeBytes == other.sizeBytes &&
          isWatermarked == other.isWatermarked &&
          isPinned == other.isPinned &&
          securityStatus == other.securityStatus;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        type,
        groupId,
        uploadedBy,
        ownerId,
        uploadedAt,
        sizeBytes,
        isWatermarked,
        isPinned,
        securityStatus,
      );
}
