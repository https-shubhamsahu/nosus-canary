import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../files/presentation/providers/upload_provider.dart';
import '../../groups/models/group_file.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../groups/providers/groups_provider.dart';
import '../../groups/domain/models/study_group.dart';
import '../../groups/screens/group_detail_screen.dart';
import '../../../../components/spyglass_viewer.dart';
import '../../../../core/utils/debug_logger.dart';
import '../../../../main.dart';

class RecentlySavedItem {
  final String id;
  final String title;
  final String type; // 'pdf', 'image', 'text', 'url'
  final String destinationType; // 'vault' or 'group'
  final String destinationName; // 'Private Vault' or group name
  final String? destinationId; // group ID if group
  final DateTime timestamp;
  final String status; // 'uploading', 'completed', 'failed'
  final String? localPath; // temp cache path for retry
  final String? extraData; // extra context (shared content)
  final String? fileId; // resolved file ID from Supabase

  RecentlySavedItem({
    required this.id,
    required this.title,
    required this.type,
    required this.destinationType,
    required this.destinationName,
    this.destinationId,
    required this.timestamp,
    required this.status,
    this.localPath,
    this.extraData,
    this.fileId,
  });

  RecentlySavedItem copyWith({
    String? id,
    String? title,
    String? type,
    String? destinationType,
    String? destinationName,
    String? destinationId,
    DateTime? timestamp,
    String? status,
    String? localPath,
    String? extraData,
    String? fileId,
  }) {
    return RecentlySavedItem(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      destinationType: destinationType ?? this.destinationType,
      destinationName: destinationName ?? this.destinationName,
      destinationId: destinationId ?? this.destinationId,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      localPath: localPath ?? this.localPath,
      extraData: extraData ?? this.extraData,
      fileId: fileId ?? this.fileId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'destinationType': destinationType,
      'destinationName': destinationName,
      'destinationId': destinationId,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
      'localPath': localPath,
      'extraData': extraData,
      'fileId': fileId,
    };
  }

  factory RecentlySavedItem.fromMap(Map<String, dynamic> map) {
    return RecentlySavedItem(
      id: map['id'] as String,
      title: map['title'] as String,
      type: map['type'] as String,
      destinationType: map['destinationType'] as String,
      destinationName: map['destinationName'] as String,
      destinationId: map['destinationId'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      status: map['status'] as String,
      localPath: map['localPath'] as String?,
      extraData: map['extraData'] as String?,
      fileId: map['fileId'] as String?,
    );
  }
}

class RecentlySavedState {
  final List<RecentlySavedItem> items;
  final String? activeUploadId;

  const RecentlySavedState({
    this.items = const [],
    this.activeUploadId,
  });

  RecentlySavedState copyWith({
    List<RecentlySavedItem>? items,
    String? activeUploadId,
  }) {
    return RecentlySavedState(
      items: items ?? this.items,
      activeUploadId: activeUploadId ?? this.activeUploadId,
    );
  }
}

class RecentlySavedNotifier extends Notifier<RecentlySavedState> {
  static const _keyPrefix = 'recently_saved_history_v2_';

  @override
  RecentlySavedState build() {
    final user = ref.watch(authStateProvider).value;
    
    if (user != null) {
      _loadFromPrefs(user.id);
    } else {
      state = const RecentlySavedState();
    }
    return const RecentlySavedState();
  }

  Future<void> _loadFromPrefs(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!ref.mounted) return;
      final jsonStr = prefs.getString('$_keyPrefix$userId');
      if (jsonStr != null) {
        final List decoded = json.decode(jsonStr);
        var loadedItems = decoded.map((x) => RecentlySavedItem.fromMap(Map<String, dynamic>.from(x))).toList();

        loadedItems = loadedItems.map((item) {
          if (item.status == 'uploading') {
            return item.copyWith(status: 'failed');
          }
          return item;
        }).toList();

        state = state.copyWith(items: loadedItems);
      } else {
        state = const RecentlySavedState();
      }
    } catch (e) {
      debugLog("Error loading recently saved history: $e");
    }
  }

  Future<void> _saveToPrefs() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = json.encode(state.items.map((x) => x.toMap()).toList());
      await prefs.setString('$_keyPrefix${user.id}', jsonStr);
    } catch (e) {
      debugLog("Error saving recently saved history: $e");
    }
  }

  void addItem(RecentlySavedItem item) {
    var items = List<RecentlySavedItem>.from(state.items);
    items.removeWhere((x) => x.id == item.id);
    items.removeWhere((x) => x.extraData == item.extraData && x.destinationId == item.destinationId && x.destinationType == item.destinationType);

    items.insert(0, item);
    if (items.length > 20) {
      final toRemove = items.sublist(20);
      for (final oldItem in toRemove) {
        _deleteLocalFile(oldItem.localPath);
      }
      items = items.sublist(0, 20);
    }
    state = state.copyWith(
      items: items,
      activeUploadId: item.status == 'uploading' ? item.id : state.activeUploadId,
    );
    _saveToPrefs();
  }

  void updateStatus(String id, String status) {
    final items = state.items.map((x) {
      if (x.id == id) {
        if (status == 'completed') {
          _deleteLocalFile(x.localPath);
        }
        return x.copyWith(status: status);
      }
      return x;
    }).toList();
    
    state = state.copyWith(
      items: items,
      activeUploadId: status == 'uploading' ? id : (state.activeUploadId == id ? null : state.activeUploadId),
    );
    _saveToPrefs();
  }

  void updateItemFileId(String id, String? fileId) {
    final items = state.items.map((x) {
      if (x.id == id) {
        return x.copyWith(fileId: fileId);
      }
      return x;
    }).toList();
    state = state.copyWith(items: items);
    _saveToPrefs();
  }

  void removeItem(String id) {
    final item = state.items.firstWhere((x) => x.id == id, orElse: () => RecentlySavedItem(
      id: '', title: '', type: '', destinationType: '', destinationName: '', timestamp: DateTime.now(), status: ''
    ));
    if (item.id.isNotEmpty) {
      _deleteLocalFile(item.localPath);
    }
    final items = state.items.where((x) => x.id != id).toList();
    state = state.copyWith(
      items: items,
      activeUploadId: state.activeUploadId == id ? null : state.activeUploadId,
    );
    _saveToPrefs();
  }

  void _deleteLocalFile(String? path) {
    if (path == null) return;
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
        debugLog("Deleted cache file: $path");
      }
    } catch (e) {
      debugLog("Error deleting cache file: $e");
    }
  }

  Future<void> retryUpload(String itemId, WidgetRef ref) async {
    final item = state.items.firstWhere((x) => x.id == itemId, orElse: () => RecentlySavedItem(
      id: '', title: '', type: '', destinationType: '', destinationName: '', timestamp: DateTime.now(), status: ''
    ));
    if (item.id.isEmpty) return;

    updateStatus(itemId, 'uploading');

    try {
      final uploadNotifier = ref.read(uploadProvider.notifier);
      final targetGroupId = item.destinationId ?? '';

      if (item.type == 'pdf' || item.type == 'image') {
        final filePath = item.localPath;
        if (filePath == null) throw Exception("Cached file path is missing");
        final file = File(filePath);
        if (!await file.exists()) {
          throw Exception("Cached file no longer exists");
        }
        final bytes = await file.readAsBytes();
        final type = item.type == 'pdf' ? FileType.pdf : FileType.image;
        await uploadNotifier.uploadDocument(item.title, type, targetGroupId, bytes);
      } else if (item.type == 'text') {
        if (item.destinationType == 'vault') {
          final user = ref.read(authRepositoryProvider).currentUser;
          if (user == null) throw Exception("User not authenticated");
          
          await uploadNotifier.savePrivateNote(userId: user.id, content: item.extraData ?? '');
        } else {
          final bytes = Uint8List.fromList(utf8.encode(item.extraData ?? ''));
          await uploadNotifier.uploadDocument(item.title, FileType.markdown, targetGroupId, bytes);
        }
      } else if (item.type == 'url') {
        final trimmed = (item.extraData ?? '').trim();
        final isDrive = trimmed.contains('drive.google.com') || trimmed.contains('docs.google.com');
        if (isDrive) {
          await uploadNotifier.linkGoogleDriveDocument(item.title, targetGroupId, trimmed);
        } else {
          final mdContent = '# Shared Reference Link\n\nURL: [$trimmed]($trimmed)\n\nShared on: ${DateTime.now().toLocal()}\n';
          final bytes = Uint8List.fromList(utf8.encode(mdContent));
          await uploadNotifier.uploadDocument(item.title, FileType.markdown, targetGroupId, bytes);
        }
      }

      final uploadState = ref.read(uploadProvider);
      if (uploadState.stage == UploadStage.complete) {
        updateStatus(itemId, 'completed');
      } else {
        updateStatus(itemId, 'failed');
      }
    } catch (e) {
      debugLog("Retry upload failed: $e");
      updateStatus(itemId, 'failed');
    }
  }

  /// Whether the signed-in user is still a member of [groupId], per the
  /// server-backed group list rather than anything cached in this history
  /// entry. Returns false while the list is still loading — deny-by-default is
  /// the right side to err on, and the user can tap again.
  bool _isStillMember(String groupId, WidgetRef ref) {
    final groups = ref.read(groupsProvider).value ?? [];
    return groups.any((g) => g.id == groupId);
  }

  void navigateToItem(RecentlySavedItem item, BuildContext context, WidgetRef ref) async {
    if (item.status != 'completed') return;

    if (item.type == 'url') {
      final trimmed = (item.extraData ?? '').trim();
      final isDrive = trimmed.contains('drive.google.com') || trimmed.contains('docs.google.com');
      
      if (isDrive && item.fileId != null && item.destinationId != null) {
        // Same membership gate the non-Drive branch below applies. This entry
        // is replayed from SharedPreferences, so it outlives leaving the group
        // — without the check, a stale history row is a live door into a group
        // the user is no longer in. The server refuses the fetch either way
        // (drive-proxy resolves the file to its group and requires
        // membership), so this is the fast, honest failure rather than the
        // only barrier.
        if (!_isStillMember(item.destinationId!, ref)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Study Group not found or left.')),
          );
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SpyglassViewer(
              fileId: item.fileId!,
              groupId: item.destinationId!,
              documentTitle: item.title,
              documentCategory: 'pdf',
            ),
          ),
        );
      } else {
        const channel = MethodChannel('co.nosus.app/share');
        try {
          await channel.invokeMethod('openUrl', {'url': trimmed});
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not open link: $e')),
            );
          }
        }
      }
    } else if (item.type == 'text' && item.destinationType == 'vault') {
      ref.read(activeTabProvider.notifier).changeTab(0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Private notepad opened.'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      if (item.destinationId != null) {
        final groupsAsync = ref.read(groupsProvider);
        final groups = groupsAsync.value ?? [];
        final matchedGroup = groups.firstWhere(
          (g) => g.id == item.destinationId,
          orElse: () => StudyGroup(
            id: '',
            name: '',
            description: '',
            members: const [],
            fileCount: 0,
            lastActivity: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        );

        if (matchedGroup.id.isNotEmpty && context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GroupDetailScreen(
                group: matchedGroup,
                highlightedFileId: item.fileId,
              ),
            ),
          );
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Study Group not found or left.')),
          );
        }
      }
    }
  }
}

final recentlySavedProvider = NotifierProvider<RecentlySavedNotifier, RecentlySavedState>(() {
  return RecentlySavedNotifier();
});
