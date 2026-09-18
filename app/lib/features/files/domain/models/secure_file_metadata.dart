enum SecureFileType { pdf, image, note, scan }

enum SecureFileStatus { secured, processing, pending }

class SecureFileMetadata {
  final String id;
  final String groupId;
  final String name;
  final SecureFileType type;
  final int sizeBytes;
  final String uploaderName;
  final DateTime uploadedAt;
  final bool isWatermarked;
  final bool isPinned;
  final SecureFileStatus status;

  const SecureFileMetadata({
    required this.id,
    required this.groupId,
    required this.name,
    required this.type,
    required this.sizeBytes,
    required this.uploaderName,
    required this.uploadedAt,
    this.isWatermarked = true,
    this.isPinned = false,
    this.status = SecureFileStatus.secured,
  });
}
