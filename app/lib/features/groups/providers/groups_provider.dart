import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/study_group.dart';
import '../domain/repositories/study_group_repository.dart';
import '../models/group_file.dart';
import '../../../services/supabase_service.dart';
import '../presentation/providers/group_dependencies.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../files/domain/models/secure_file_metadata.dart';
import '../../files/presentation/providers/secure_file_providers.dart';
import '../../../core/utils/debug_logger.dart';

// ─── Search query ─────────────────────────────────────────────────────────────

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String value) => state = value;
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

// ─── Groups list ──────────────────────────────────────────────────────────────

class GroupsNotifier extends AsyncNotifier<List<StudyGroup>> {
  StreamSubscription? _sub;
  static const _cacheKeyPrefix = 'groups_cache_v2_';

  @override
  Future<List<StudyGroup>> build() async {
    final authState = ref.watch(authStateProvider);
    final user = authState.value;
    
    _sub?.cancel();
    ref.onDispose(() => _sub?.cancel());

    if (user == null) {
      return const [];
    }

    final repo = ref.watch(studyGroupRepositoryProvider);
    _sub = repo.watchGroups().listen(
      (data) {
        state = AsyncValue.data(data);
        _saveCache(user.id, data);
      },
      onError: (err, stack) {
        debugLog("GroupsNotifier: Realtime stream error: $err");
      },
    );

    // Stale-while-revalidate: paint the last-known list immediately (no
    // spinner on a warm start), then let the fetch/stream replace it.
    final cached = await _loadCache(user.id);
    if (cached != null && cached.isNotEmpty) {
      state = AsyncValue.data(cached);
    }

    try {
      final fresh = await repo.getGroups();
      _saveCache(user.id, fresh);
      return fresh;
    } catch (e) {
      debugLog("GroupsNotifier: REST fetch error: $e");
      // Offline with a cache beats an empty screen.
      return cached ?? const [];
    }
  }

  Future<List<StudyGroup>?> _loadCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_cacheKeyPrefix$userId');
      if (raw == null) return null;
      return (jsonDecode(raw) as List<dynamic>)
          .map((g) => StudyGroup.fromJson(g as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null; // corrupt/old-schema cache is simply ignored
    }
  }

  Future<void> _saveCache(String userId, List<StudyGroup> groups) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_cacheKeyPrefix$userId',
        jsonEncode(groups.map((g) => g.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> createGroup(StudyGroup group) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(studyGroupRepositoryProvider);
      await repo.createGroup(group);
    } catch (e, st) {
      // Re-thrown (not just stored in state) so callers that await this can
      // actually show the failure instead of treating it as success.
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> joinGroupByName(String name) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(studyGroupRepositoryProvider);
      final userId = SupabaseService.instance.isReachable ? Supabase.instance.client.auth.currentUser?.id : null;
      if (userId != null) {
        await repo.joinGroupByName(name, userId);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> joinByInviteCode(String inviteCode) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(studyGroupRepositoryProvider);
      final userId = SupabaseService.instance.isReachable ? Supabase.instance.client.auth.currentUser?.id : null;
      if (userId != null) {
        await repo.joinGroupByInviteCode(inviteCode, userId);
      } else {
        throw Exception("You must be logged in to join a group.");
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> leaveGroup(String groupId) async {
    final repo = ref.read(studyGroupRepositoryProvider);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      await repo.leaveGroup(groupId, userId);
    }
  }

  Future<void> deleteGroup(String groupId) async {
    final repo = ref.read(studyGroupRepositoryProvider);
    await repo.deleteGroup(groupId);
  }

  // Moderation. These deliberately do not set `state` to loading/error: the
  // groups list is not what changed, and blanking the whole screen because one
  // member row is being updated would be a worse experience than the operation
  // it is reporting. Failures propagate to the caller, which shows them in
  // context. `groupMembersProvider` is invalidated so the member list reflects
  // the change immediately rather than waiting on the realtime round trip.

  Future<void> removeMember(String groupId, String memberId) async {
    await ref.read(studyGroupRepositoryProvider).removeMember(groupId, memberId);
    ref.invalidate(groupMembersProvider(groupId));
  }

  Future<void> setMemberRole(String groupId, String memberId, bool isAdmin) async {
    await ref
        .read(studyGroupRepositoryProvider)
        .setMemberRole(groupId, memberId, isAdmin);
    ref.invalidate(groupMembersProvider(groupId));
  }

  Future<void> banMember(String groupId, String memberId, {String? reason}) async {
    await ref
        .read(studyGroupRepositoryProvider)
        .banMember(groupId, memberId, reason: reason);
    ref.invalidate(groupMembersProvider(groupId));
    ref.invalidate(groupBansProvider(groupId));
  }

  Future<void> unbanMember(String groupId, String memberId) async {
    await ref.read(studyGroupRepositoryProvider).unbanMember(groupId, memberId);
    ref.invalidate(groupBansProvider(groupId));
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(studyGroupRepositoryProvider);
      final groups = await repo.getGroups();
      state = AsyncValue.data(groups);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final groupsProvider = AsyncNotifierProvider<GroupsNotifier, List<StudyGroup>>(
  GroupsNotifier.new,
);

/// Filtered groups based on the current search query.
final filteredGroupsProvider = Provider<AsyncValue<List<StudyGroup>>>((ref) {
  final query = ref.watch(searchQueryProvider).toLowerCase().trim();
  final groupsAsync = ref.watch(groupsProvider);

  return groupsAsync.whenData((groups) {
    if (query.isEmpty) return groups;
    return groups
        .where(
          (g) =>
              g.name.toLowerCase().contains(query) ||
              g.description.toLowerCase().contains(query),
        )
        .toList();
  });
});

// ─── Group files ──────────────────────────────────────────────────────────────

class GroupFilesNotifier extends AsyncNotifier<Map<String, List<GroupFile>>> {
  StreamSubscription? _sub;
  static const _listEquality = ListEquality<GroupFile>();

  @override
  Future<Map<String, List<GroupFile>>> build() async {
    final authState = ref.watch(authStateProvider);
    final user = authState.value;
    
    _sub?.cancel();
    ref.onDispose(() => _sub?.cancel());

    if (user == null) {
      return const {};
    }

    final repo = ref.watch(secureFileRepositoryProvider);
    _sub = repo.watchAllFiles().listen(
      (data) {
        state = AsyncValue.data(_buildFilesMap(data));
      },
      onError: (err, stack) {
        // Just log the error (e.g. websocket offline) to keep the REST data visible
        debugLog("GroupFilesNotifier: Realtime stream error: $err");
      },
    );

    try {
      final initialData = await repo.getAllFiles();
      return _buildFilesMap(initialData);
    } catch (e) {
      debugLog("GroupFilesNotifier: REST fetch error: $e");
      return const {};
    }
  }

  /// Groups the flat file list by groupId, reusing the previous state's list
  /// instance for any group whose files didn't actually change content —
  /// this is what lets `groupFilesForGroupProvider`'s `.select()` correctly
  /// skip rebuilding widgets for groups that weren't touched by an update
  /// (Dart's `List` uses identity equality, so a scoped `.select()` only
  /// short-circuits when it gets back the *same* list object).
  Map<String, List<GroupFile>> _buildFilesMap(List<SecureFileMetadata> data) {
    final previous = state.value;
    final grouped = <String, List<GroupFile>>{};
    for (final file in data) {
      grouped.putIfAbsent(file.groupId, () => []).add(_mapMetadata(file));
    }
    if (previous == null) return grouped;

    final filesMap = <String, List<GroupFile>>{};
    for (final entry in grouped.entries) {
      final oldList = previous[entry.key];
      filesMap[entry.key] =
          oldList != null && _listEquality.equals(oldList, entry.value)
              ? oldList
              : entry.value;
    }
    return filesMap;
  }

  void addFile(String groupId, GroupFile file) {
    // Left for direct calls/testing, but upload is now handled via uploadProvider
  }

  Future<void> removeFile(String groupId, String fileId) async {
    final repo = ref.read(secureFileRepositoryProvider);
    await repo.deleteFile(groupId, fileId);
  }

  Future<void> togglePin(String groupId, String fileId) async {
    final repo = ref.read(secureFileRepositoryProvider);
    await repo.togglePin(groupId, fileId);
  }

  Future<void> renameFile(String fileId, String newName) async {
    final repo = ref.read(secureFileRepositoryProvider);
    await repo.renameFile(fileId, newName);
  }

  GroupFile _mapMetadata(SecureFileMetadata metadata) {
    final fileType = metadata.type == SecureFileType.note
        ? FileType.markdown
        : FileType.values.firstWhere(
            (e) => e.name == metadata.type.name,
            orElse: () => FileType.pdf,
          );

    final securityStatus = FileSecurityStatus.values.firstWhere(
      (e) => e.name == metadata.status.name,
      orElse: () => FileSecurityStatus.secured,
    );


    return GroupFile(
      id: metadata.id,
      name: metadata.name,
      type: fileType,
      groupId: metadata.groupId,
      uploadedBy: metadata.uploaderName,
      ownerId: metadata.uploaderName,
      uploadedAt: metadata.uploadedAt,
      sizeBytes: metadata.sizeBytes,
      isWatermarked: metadata.isWatermarked,
      isPinned: metadata.isPinned,
      securityStatus: securityStatus,
    );
  }
}

final groupFilesProvider =
    AsyncNotifierProvider<GroupFilesNotifier, Map<String, List<GroupFile>>>(
      GroupFilesNotifier.new,
    );

/// Files for a single group, derived from [groupFilesProvider] with a
/// content-aware `.select()` (via [GroupFile]'s value equality) so a
/// single-group screen only rebuilds when *that* group's files actually
/// change, not on every unrelated group's update.
final groupFilesForGroupProvider =
    Provider.family<AsyncValue<List<GroupFile>>, String>((ref, groupId) {
  return ref.watch(
    groupFilesProvider.select(
      (async) => async.whenData((map) => map[groupId] ?? const <GroupFile>[]),
    ),
  );
});

final groupMembersProvider = StreamProvider.family<List<GroupMember>, String>((ref, groupId) {
  if (SupabaseService.instance.isConfigured && SupabaseService.instance.isReachable) {
    final client = Supabase.instance.client;
    final controller = StreamController<List<GroupMember>>();
    StreamSubscription? sub;

    void fetchAndAdd() async {
      try {
        final rows = await client
            .from('study_group_members')
            .select('user_id, is_admin, profiles(display_name, email)')
            .eq('group_id', groupId);

        final list = <GroupMember>[];
        for (var r in rows as List) {
          final id = r['user_id'] as String;
          final profile = r['profiles'] ?? {};
          final name = profile['display_name'] as String? ??
              (profile['email'] as String? ?? 'User').split('@').first;
          final initials = name.isNotEmpty
              ? name.substring(0, name.length >= 2 ? 2 : name.length).toUpperCase()
              : 'US';
          list.add(GroupMember(
            id: id,
            name: name,
            initials: initials,
            isAdmin: r['is_admin'] as bool? ?? false,
          ));
        }

        if (!controller.isClosed) {
          controller.add(list);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    // Listen to changes in the study_group_members table for this group
    sub = client
        .from('study_group_members')
        .stream(primaryKey: ['group_id', 'user_id'])
        .eq('group_id', groupId)
        .listen((_) => fetchAndAdd());

    // Initial fetch
    fetchAndAdd();

    ref.onDispose(() {
      sub?.cancel();
      controller.close();
    });

    return controller.stream;
  } else {
    return Stream.value(<GroupMember>[]);
  }
});

/// People barred from rejoining [groupId].
///
/// Visible to every member, not just admins — moderation that only moderators
/// can see is not accountable, which is the same reasoning that makes the audit
/// log group-visible. The RLS policy on `group_bans` matches: members read,
/// only the RPCs write.
final groupBansProvider =
    FutureProvider.family<List<GroupBan>, String>((ref, groupId) async {
  if (!SupabaseService.instance.isConfigured ||
      !SupabaseService.instance.isReachable) {
    return const [];
  }
  return ref.read(studyGroupRepositoryProvider).getBans(groupId);
});
