import '../models/study_group.dart';

/// A person barred from rejoining a group.
class GroupBan {
  final String userId;
  final String displayName;
  final String? reason;
  final DateTime bannedAt;

  const GroupBan({
    required this.userId,
    required this.displayName,
    required this.reason,
    required this.bannedAt,
  });
}

abstract interface class StudyGroupRepository {
  Stream<List<StudyGroup>> watchGroups();

  Future<void> createGroup(StudyGroup group);

  Future<void> ensureCommunityExists(String name, String description, bool isPublic);
  Future<void> joinGroupByName(String name, String userId);
  Future<void> joinGroupByInviteCode(String inviteCode, String userId);
  Future<void> leaveGroup(String groupId, String userId);
  Future<void> deleteGroup(String groupId);

  // ── Moderation ─────────────────────────────────────────────────────────────
  // Each of these maps to a SECURITY DEFINER RPC that re-checks admin rights
  // server-side and writes its own audit entry in the same transaction. The
  // client cannot perform any of them by writing to a table directly, and
  // hiding the buttons is not what stops a non-admin — the database is.

  /// Removes [memberId] from the group. Throws if the caller is not an admin,
  /// or if this would remove the group's last admin.
  Future<void> removeMember(String groupId, String memberId);

  /// Promotes or demotes [memberId]. Throws if the caller is not an admin, or
  /// if this would demote the group's last admin.
  Future<void> setMemberRole(String groupId, String memberId, bool isAdmin);

  /// Removes [memberId] and blocks them from rejoining with any invite.
  Future<void> banMember(String groupId, String memberId, {String? reason});

  /// Restores [memberId]'s eligibility to accept an invite. Does not re-add
  /// them to the group.
  Future<void> unbanMember(String groupId, String memberId);

  Future<List<GroupBan>> getBans(String groupId);

  Future<List<StudyGroup>> getGroups();
}
