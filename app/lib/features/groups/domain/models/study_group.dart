import 'package:flutter/foundation.dart';

// ─── GroupMember ──────────────────────────────────────────────────────────────

@immutable
class GroupMember {
  final String id;
  final String name;
  final String initials;
  final bool isAdmin;

  const GroupMember({
    required this.id,
    required this.name,
    required this.initials,
    this.isAdmin = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'initials': initials,
        'isAdmin': isAdmin,
      };

  factory GroupMember.fromJson(Map<String, dynamic> json) => GroupMember(
        id: json['id'] as String,
        name: json['name'] as String,
        initials: json['initials'] as String? ?? '?',
        isAdmin: json['isAdmin'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupMember &&
          id == other.id &&
          name == other.name &&
          initials == other.initials &&
          isAdmin == other.isAdmin;

  @override
  int get hashCode => Object.hash(id, name, initials, isAdmin);
}

// ─── StudyGroup ───────────────────────────────────────────────────────────────

@immutable
class StudyGroup {
  final String id;
  final String name;
  final String description;
  final List<GroupMember> members;
  final int fileCount;
  final DateTime lastActivity;
  final bool isWatermarkEnabled;
  final String? inviteCode;

  const StudyGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.members,
    required this.fileCount,
    required this.lastActivity,
    this.isWatermarkEnabled = true,
    this.inviteCode,
  });

  int get memberCount => members.length;

  String get lastActivityLabel {
    final diff = DateTime.now().difference(lastActivity);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${lastActivity.day}/${lastActivity.month}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'members': members.map((m) => m.toJson()).toList(),
        'fileCount': fileCount,
        'lastActivity': lastActivity.toIso8601String(),
        'isWatermarkEnabled': isWatermarkEnabled,
        'inviteCode': inviteCode,
      };

  factory StudyGroup.fromJson(Map<String, dynamic> json) => StudyGroup(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        members: (json['members'] as List<dynamic>? ?? const [])
            .map((m) => GroupMember.fromJson(m as Map<String, dynamic>))
            .toList(),
        fileCount: json['fileCount'] as int? ?? 0,
        lastActivity: DateTime.tryParse(json['lastActivity'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        isWatermarkEnabled: json['isWatermarkEnabled'] as bool? ?? true,
        inviteCode: json['inviteCode'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudyGroup &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          listEquals(members, other.members) &&
          fileCount == other.fileCount &&
          lastActivity == other.lastActivity &&
          isWatermarkEnabled == other.isWatermarkEnabled &&
          inviteCode == other.inviteCode;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        description,
        Object.hashAll(members),
        fileCount,
        lastActivity,
        isWatermarkEnabled,
        inviteCode,
      );
}
