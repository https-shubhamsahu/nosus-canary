import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../theme.dart';
import '../../../../services/share_intent_service.dart';
import '../../../../services/supabase_service.dart';
import '../../../groups/providers/groups_provider.dart';
import '../../../groups/domain/models/study_group.dart';
import '../../../groups/models/group_file.dart';
import '../../../files/presentation/providers/upload_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../providers/recently_saved_provider.dart';
import '../../../../core/utils/debug_logger.dart';

class SaveToNoSusDialog extends ConsumerStatefulWidget {
  final SharedContent content;

  const SaveToNoSusDialog({super.key, required this.content});

  @override
  ConsumerState<SaveToNoSusDialog> createState() => _SaveToNoSusDialogState();
}

class _SaveToNoSusDialogState extends ConsumerState<SaveToNoSusDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _checkController;
  late Animation<double> _checkProgress;

  bool _isVaultSelected = true;
  String? _selectedGroupId;
  String _textSaveType = 'private'; // 'private' or 'group'

  List<String> _pinnedGroupIds = [];
  bool _isLoadingPrefs = true;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkProgress = CurvedAnimation(
      parent: _checkController,
      curve: Curves.easeOut,
    );
    _loadPreferences();
  }

  @override
  void dispose() {
    _checkController.dispose();
    _cleanupTempFile();
    super.dispose();
  }

  void _cleanupTempFile() {
    if (widget.content.type == 'pdf' || widget.content.type == 'image') {
      try {
        final file = File(widget.content.data);
        if (file.existsSync()) {
          file.deleteSync();
          debugLog("Cleaned up temporary cache file: ${widget.content.data}");
        }
      } catch (e) {
        debugLog("Error cleaning up temporary cache file: $e");
      }
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pinned = prefs.getStringList('pinned_group_ids') ?? [];
      final lastDest = prefs.getString('last_save_destination');

      if (mounted) {
        setState(() {
          _pinnedGroupIds = pinned;
          _isLoadingPrefs = false;

          if (lastDest != null) {
            if (lastDest == 'vault') {
              _isVaultSelected = true;
            } else if (lastDest.startsWith('group_')) {
              _isVaultSelected = false;
              _selectedGroupId = lastDest.substring(6);
            }
          }
        });
      }
    } catch (e) {
      debugLog("Error loading preferences: $e");
      if (mounted) {
        setState(() => _isLoadingPrefs = false);
      }
    }
  }

  Future<void> _togglePin(String groupId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final updated = List<String>.from(_pinnedGroupIds);
      if (updated.contains(groupId)) {
        updated.remove(groupId);
      } else {
        updated.add(groupId);
      }
      await prefs.setStringList('pinned_group_ids', updated);
      if (mounted) {
        setState(() {
          _pinnedGroupIds = updated;
        });
      }
      HapticFeedback.lightImpact();
    } catch (e) {
      debugLog("Error saving pinned groups: $e");
    }
  }

  Future<void> _saveDestinationPreference(String dest) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_save_destination', dest);
    } catch (_) {}
  }

  Future<String> _getOrCreatePrivateVaultGroup() async {
    final groupsAsync = ref.read(groupsProvider);
    final groups = groupsAsync.value ?? [];

    // Check if "Study Vault (Private)" already exists
    final privateGroup = groups.firstWhere(
      (g) => g.name == 'Study Vault (Private)',
      orElse: () => StudyGroup(
        id: '',
        name: '',
        description: '',
        members: const [],
        fileCount: 0,
        lastActivity: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );

    if (privateGroup.id.isNotEmpty) {
      return privateGroup.id;
    }

    // Create a new private group
    final currentUser = ref.read(authRepositoryProvider).currentUser;
    final userId = currentUser?.id ?? 'me';
    final userEmail = currentUser?.email ?? 'You';
    final cleanEmailPrefix = userEmail.contains('@')
        ? userEmail.split('@').first
        : '';
    final userInitials = cleanEmailPrefix.isNotEmpty
        ? cleanEmailPrefix
              .substring(
                0,
                cleanEmailPrefix.length >= 2 ? 2 : cleanEmailPrefix.length,
              )
              .toUpperCase()
        : 'ME';

    final groupId = 'g_private_${DateTime.now().millisecondsSinceEpoch}';
    final newGroup = StudyGroup(
      id: groupId,
      name: 'Study Vault (Private)',
      description: 'Your private secure vault for personal documents.',
      members: [
        GroupMember(
          id: userId,
          name: userEmail,
          initials: userInitials,
          isAdmin: true,
        ),
      ],
      fileCount: 0,
      lastActivity: DateTime.now(),
      isWatermarkEnabled: true,
      inviteCode: null,
    );

    await ref.read(groupsProvider.notifier).createGroup(newGroup);
    return groupId;
  }

  Future<void> _handleSave() async {
    final uploadNotifier = ref.read(uploadProvider.notifier);

    // Resolve Title
    final contentType = widget.content.type;
    String title = '';
    if (contentType == 'pdf' || contentType == 'image') {
      title =
          widget.content.name ??
          File(widget.content.data).uri.pathSegments.last;
    } else if (contentType == 'text') {
      title = _textSaveType == 'private' ? 'Private Note' : 'Group Note';
    } else if (contentType == 'url') {
      final trimmed = widget.content.data.trim();
      final isDrive =
          trimmed.contains('drive.google.com') ||
          trimmed.contains('docs.google.com');
      title = isDrive ? 'Linked Drive File' : 'Reference Link';
    }

    // Resolve Destination Type & Name
    final destType = _isVaultSelected ? 'vault' : 'group';
    String destName = 'Private Vault';
    String? targetGroupId;

    final groupsAsync = ref.read(groupsProvider);
    final groups = groupsAsync.value ?? [];

    String? loggedItemId;

    try {
      if (_isVaultSelected) {
        targetGroupId = await _getOrCreatePrivateVaultGroup();
        await _saveDestinationPreference('vault');
      } else {
        if (_selectedGroupId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a Study Group')),
          );
          return;
        }
        targetGroupId = _selectedGroupId!;
        await _saveDestinationPreference('group_$_selectedGroupId');

        final matchedGroup = groups.firstWhere(
          (g) => g.id == targetGroupId,
          orElse: () => StudyGroup(
            id: '',
            name: 'Study Group',
            description: '',
            members: const [],
            fileCount: 0,
            lastActivity: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        );
        destName = matchedGroup.name;
      }

      // 1. Log to history as uploading
      final itemId = 'saved_${DateTime.now().millisecondsSinceEpoch}';
      loggedItemId = itemId;
      final newItem = RecentlySavedItem(
        id: itemId,
        title: title,
        type: contentType,
        destinationType: destType,
        destinationName: destName,
        destinationId: destType == 'group' ? targetGroupId : null,
        timestamp: DateTime.now(),
        status: 'uploading',
        localPath: (contentType == 'pdf' || contentType == 'image')
            ? widget.content.data
            : null,
        extraData: widget.content.data,
      );
      ref.read(recentlySavedProvider.notifier).addItem(newItem);

      // 2. Perform Save
      if (contentType == 'pdf' || contentType == 'image') {
        final filePath = widget.content.data;
        final file = File(filePath);
        if (!await file.exists()) {
          throw Exception("File does not exist on disk: $filePath");
        }
        final bytes = await file.readAsBytes();
        final name = widget.content.name ?? file.uri.pathSegments.last;
        final type = contentType == 'pdf' ? FileType.pdf : FileType.image;

        await uploadNotifier.uploadDocument(name, type, targetGroupId, bytes);
      } else if (contentType == 'text') {
        if (_textSaveType == 'private') {
          final user = ref.read(authRepositoryProvider).currentUser;
          if (user == null) throw Exception("User not authenticated");

          final existing = await SupabaseService.instance.fetchUserNote(
            user.id,
          );
          final divider =
              '\n\n---\n### 📥 Shared Note (${DateTime.now().toLocal().toString().substring(0, 16)})\n${widget.content.data}\n';
          final newContent = existing.isEmpty
              ? widget.content.data
              : '$existing$divider';

          await uploadNotifier.savePrivateNote(
            userId: user.id,
            content: newContent,
          );
        } else {
          final name =
              'Shared Note ${DateTime.now().millisecondsSinceEpoch % 1000}';
          final bytes = Uint8List.fromList(utf8.encode(widget.content.data));

          await uploadNotifier.uploadDocument(
            name,
            FileType.markdown,
            targetGroupId,
            bytes,
          );
        }
      } else if (contentType == 'url') {
        final trimmed = widget.content.data.trim();
        final isDrive =
            trimmed.contains('drive.google.com') ||
            trimmed.contains('docs.google.com');

        if (isDrive) {
          final name =
              'Linked Drive File ${DateTime.now().millisecondsSinceEpoch % 1000}';
          await uploadNotifier.linkGoogleDriveDocument(
            name,
            targetGroupId,
            trimmed,
          );
        } else {
          final name =
              'Reference Link ${DateTime.now().millisecondsSinceEpoch % 1000}';
          final mdContent =
              '# Shared Reference Link\n\nURL: [${widget.content.data}](${widget.content.data})\n\nShared on: ${DateTime.now().toLocal()}\n';
          final bytes = Uint8List.fromList(utf8.encode(mdContent));

          await uploadNotifier.uploadDocument(
            name,
            FileType.markdown,
            targetGroupId,
            bytes,
          );
        }
      }

      // 3. Trigger checkmark success animation and dismiss on success
      final uploadState = ref.read(uploadProvider);
      if (uploadState.stage == UploadStage.complete) {
        ref
            .read(recentlySavedProvider.notifier)
            .updateStatus(itemId, 'completed');
        HapticFeedback.mediumImpact();
        _checkController.forward();
        await Future.delayed(const Duration(milliseconds: 1600));
        if (mounted) {
          ref.read(shareIntentProvider.notifier).clear();
          Navigator.of(context).pop();
        }
      } else if (uploadState.stage == UploadStage.error) {
        ref.read(recentlySavedProvider.notifier).updateStatus(itemId, 'failed');
      }
    } catch (e) {
      if (loggedItemId != null) {
        ref
            .read(recentlySavedProvider.notifier)
            .updateStatus(loggedItemId, 'failed');
      }
      debugLog("Error in SaveToNoSusDialog _handleSave: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;
    final bg = isDark ? const Color(0xFF141414) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1C1C1C) : Colors.grey[100];
    final subtle = isDark
        ? NoSusTheme.dTextSecondary
        : NoSusTheme.lTextSecondary;

    final groupsAsync = ref.watch(groupsProvider);
    final uploadState = ref.watch(uploadProvider);

    // Filter/Order Groups: Recent (sorted by lastActivity desc), Pinned (in _pinnedGroupIds), then All
    final groups = groupsAsync.value ?? [];

    // Sort groups for destination list
    final pinnedGroups = groups
        .where(
          (g) =>
              _pinnedGroupIds.contains(g.id) &&
              g.name != 'Study Vault (Private)',
        )
        .toList();
    final recentGroups = List<StudyGroup>.from(groups)
      ..where((g) => g.name != 'Study Vault (Private)')
      ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    final recent3 = recentGroups.take(3).toList();

    final allGroupsSorted = List<StudyGroup>.from(groups)
      ..where((g) => g.name != 'Study Vault (Private)')
      ..sort((a, b) => a.name.compareTo(b.name));

    // Preselect group if only 1 group exists
    final nonPrivateGroups = groups
        .where((g) => g.name != 'Study Vault (Private)')
        .toList();
    if (nonPrivateGroups.length == 1 &&
        _selectedGroupId == null &&
        !_isVaultSelected) {
      _selectedGroupId = nonPrivateGroups.first.id;
    }

    if (uploadState.stage == UploadStage.processing ||
        uploadState.stage == UploadStage.complete) {
      return Dialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (uploadState.stage == UploadStage.processing) ...[
                const SizedBox(height: 12),
                CircularProgressIndicator(
                  value: uploadState.progress,
                  color: fg,
                  backgroundColor: fg.withValues(alpha: 0.1),
                  strokeWidth: 5,
                ),
                const SizedBox(height: 24),
                Text(
                  'IMPORTING TO NO SUS...',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(uploadState.progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 14,
                    color: subtle,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () {
                    ref.read(uploadProvider.notifier).cancelUpload();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: fg,
                    side: BorderSide(color: fg.withValues(alpha: 0.2)),
                  ),
                  child: const Text('CANCEL'),
                ),
              ] else if (uploadState.stage == UploadStage.complete) ...[
                ScaleTransition(
                  scale: _checkProgress,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'SAVE COMPLETE!',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Content imported securely to NO SUS.',
                  style: TextStyle(fontSize: 13, color: subtle),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Row(
              children: [
                Icon(
                  widget.content.type == 'pdf'
                      ? Icons.picture_as_pdf_outlined
                      : widget.content.type == 'image'
                      ? Icons.image_outlined
                      : widget.content.type == 'url'
                      ? Icons.link_outlined
                      : Icons.text_snippet_outlined,
                  color: fg,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SAVE TO NO SUS',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        widget.content.type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: subtle,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Close',
                  onPressed: () {
                    ref.read(shareIntentProvider.notifier).clear();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 0.5),

          // Content Scroll Area
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Shared Content Preview Card
                  Text(
                    'SHARED CONTENT PREVIEW',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: subtle,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: fg.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.content.type == 'image') ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(widget.content.data),
                              height: 110,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (widget.content.name != null) ...[
                          Text(
                            widget.content.name!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          widget.content.type == 'image' ||
                                  widget.content.type == 'pdf'
                              ? 'Local Temp File: ${widget.content.data}'
                              : widget.content.data,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: fg.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // If Text: Ask to save as Private Note or Group Note
                  if (widget.content.type == 'text') ...[
                    Text(
                      'SAVE TEXT AS',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: subtle,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: _textSaveType == 'private',
                            label: 'Save as private note',
                            child: InkWell(
                              onTap: () =>
                                  setState(() => _textSaveType = 'private'),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _textSaveType == 'private'
                                      ? fg.withValues(alpha: 0.05)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _textSaveType == 'private'
                                        ? fg
                                        : fg.withValues(alpha: 0.1),
                                    width: _textSaveType == 'private'
                                        ? 1.5
                                        : 1.0,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.lock_outline,
                                      color: _textSaveType == 'private'
                                          ? fg
                                          : subtle,
                                      size: 20,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Private Note',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: _textSaveType == 'private'
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: _textSaveType == 'private'
                                            ? fg
                                            : subtle,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: _textSaveType == 'group',
                            label: 'Save as group note',
                            child: InkWell(
                              onTap: () =>
                                  setState(() => _textSaveType = 'group'),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _textSaveType == 'group'
                                      ? fg.withValues(alpha: 0.05)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _textSaveType == 'group'
                                        ? fg
                                        : fg.withValues(alpha: 0.1),
                                    width: _textSaveType == 'group' ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.people_outline,
                                      color: _textSaveType == 'group'
                                          ? fg
                                          : subtle,
                                      size: 20,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Group Note',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: _textSaveType == 'group'
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: _textSaveType == 'group'
                                            ? fg
                                            : subtle,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Choose Destination
                  if (widget.content.type != 'text' ||
                      _textSaveType == 'group') ...[
                    Text(
                      'CHOOSE DESTINATION',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: subtle,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Destination Cards
                    Semantics(
                      button: true,
                      selected: _isVaultSelected,
                      label: 'Destination: Study Vault, private',
                      child: InkWell(
                        onTap: () => setState(() => _isVaultSelected = true),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _isVaultSelected
                                ? fg.withValues(alpha: 0.04)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isVaultSelected
                                  ? fg
                                  : fg.withValues(alpha: 0.1),
                              width: _isVaultSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.folder_shared_outlined,
                                color: _isVaultSelected ? fg : subtle,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Study Vault (Private)',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: _isVaultSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    Text(
                                      'Secure, personal-only vault storage.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: subtle,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_isVaultSelected)
                                Icon(Icons.check_circle, color: fg, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Semantics(
                      button: true,
                      selected: !_isVaultSelected,
                      label: 'Destination: Study Group',
                      child: InkWell(
                        onTap: () => setState(() => _isVaultSelected = false),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: !_isVaultSelected
                                ? fg.withValues(alpha: 0.04)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: !_isVaultSelected
                                  ? fg
                                  : fg.withValues(alpha: 0.1),
                              width: !_isVaultSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.groups_outlined,
                                color: !_isVaultSelected ? fg : subtle,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Study Group',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: !_isVaultSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    Text(
                                      'Share securely with verified team members.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: subtle,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!_isVaultSelected)
                                Icon(Icons.check_circle, color: fg, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Group List Sub-section
                    if (!_isVaultSelected) ...[
                      const SizedBox(height: 16),
                      if (groupsAsync.isLoading || _isLoadingPrefs)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (nonPrivateGroups.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'You haven\'t joined any study groups yet.',
                            style: TextStyle(fontSize: 12, color: subtle),
                            textAlign: TextAlign.center,
                          ),
                        )
                      else ...[
                        Text(
                          'SELECT STUDY GROUP',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: subtle,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: fg.withValues(alpha: 0.08),
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListView(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            children: [
                              // 1. Recent Groups
                              if (recent3.isNotEmpty) ...[
                                _buildGroupSectionHeader(
                                  'RECENT GROUPS',
                                  subtle,
                                ),
                                ...recent3.map(
                                  (g) => _buildGroupRow(g, fg, subtle),
                                ),
                              ],

                              // 2. Pinned Groups
                              if (pinnedGroups.isNotEmpty) ...[
                                _buildGroupSectionHeader(
                                  'PINNED GROUPS',
                                  subtle,
                                ),
                                ...pinnedGroups.map(
                                  (g) => _buildGroupRow(g, fg, subtle),
                                ),
                              ],

                              // 3. All Groups
                              _buildGroupSectionHeader('ALL GROUPS', subtle),
                              ...allGroupsSorted.map(
                                (g) => _buildGroupRow(g, fg, subtle),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],

                  // Text Save Type Note
                  if (widget.content.type == 'text' &&
                      _textSaveType == 'private') ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 14, color: subtle),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Private notes are appended to your Private Notepad.',
                              style: TextStyle(fontSize: 11, color: subtle),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const Divider(height: 1, thickness: 0.5),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    ref.read(shareIntentProvider.notifier).clear();
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'CANCEL',
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.6),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: (uploadState.stage == UploadStage.processing)
                      ? null
                      : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: fg,
                    foregroundColor: bg,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'IMPORT CONTENT',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildGroupRow(StudyGroup group, Color fg, Color subtle) {
    final isSelected = _selectedGroupId == group.id;
    final isPinned = _pinnedGroupIds.contains(group.id);

    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Save to ${group.name}',
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedGroupId = group.id;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: isSelected ? fg.withValues(alpha: 0.04) : Colors.transparent,
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: isSelected ? fg : subtle,
                size: 16,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected ? fg : fg.withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      '${group.memberCount} members · ${group.fileCount} files',
                      style: TextStyle(fontSize: 10, color: subtle),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  color: isPinned ? Colors.amber : subtle,
                  size: 14,
                ),
                tooltip: isPinned ? 'Unpin ${group.name}' : 'Pin ${group.name}',
                onPressed: () => _togglePin(group.id),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
