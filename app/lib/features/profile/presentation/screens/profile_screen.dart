import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../theme.dart';
import '../../../../services/supabase_service.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../groups/domain/models/study_group.dart';
import '../../../groups/providers/groups_provider.dart';
import '../../../groups/screens/group_detail_screen.dart';
import '../../../help/domain/help_topic.dart';
import '../../../help/presentation/screens/help_topic_screen.dart';
import '../../data/avatar_processor.dart';
import '../../providers/profile_provider.dart';
import '../widgets/profile_avatar.dart';
import 'advanced_settings_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';

/// Who you are in NO SUS.
///
/// Previously this screen was profile *and* settings *and* legal text *and*
/// account deletion in one ~2,000-line scroll. Settings moved to
/// [SettingsScreen]; what is left is identity and the things that genuinely
/// describe this account.
///
/// Two "metrics" were removed rather than relocated:
///
///   * a *Contributions* score computed as `groups*10 + uploads*5 + views`,
///     which was an invented number with no meaning inside or outside the app;
///   * a *Trust Tier* of SECURE/WARNING derived by substring-matching the
///     rendered English of audit-log lines — so it flipped on the word
///     "screenshot" appearing in a description, and would have silently
///     stopped working the first time that copy was reworded.
///
/// What replaced them is the group list, which is checkable, actionable, and
/// answers a question a user actually has.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _avatarTapCount = 0;

  final List<Map<String, String>> _avatarPresets = [
    {
      'id': 'avatar_01',
      'name': 'Builder',
      'asset': 'assets/images/avatar_builder.png',
    },
    {
      'id': 'avatar_02',
      'name': 'Researcher',
      'asset': 'assets/images/avatar_researcher.png',
    },
    {
      'id': 'avatar_03',
      'name': 'Creator',
      'asset': 'assets/images/avatar_creator.png',
    },
    {
      'id': 'avatar_04',
      'name': 'Scholar',
      'asset': 'assets/images/avatar_academic.png',
    },
    {
      'id': 'avatar_05',
      'name': 'Agent',
      'asset': 'assets/images/avatar_chaos.png',
    },
    {
      'id': 'avatar_06',
      'name': 'Archivist',
      'asset': 'assets/images/avatar_archivist.png',
    },
  ];

  void _saveProfileChanges(String displayName, String avatarId, bool isCustom) {
    if (displayName.trim().isEmpty) return;
    ref
        .read(profileProvider.notifier)
        .updateProfile(
          displayName: displayName.trim(),
          avatarColorStart: jsonEncode({
            'avatar_id': avatarId,
            'is_custom': isCustom,
          }),
          avatarColorEnd: 'false',
        );
  }

  /// Five taps on the email opens diagnostics. Undocumented on purpose — it is
  /// a developer affordance, and Settings → Help & Support → Diagnostics is the
  /// discoverable route to the same screen.
  void _handleEmailTap() {
    setState(() => _avatarTapCount++);
    if (_avatarTapCount < 5) {
      HapticFeedback.lightImpact();
      return;
    }
    _avatarTapCount = 0;
    HapticFeedback.heavyImpact();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AdvancedSettingsScreen()));
  }

  Future<void> _pickAndStylePhoto() async {
    final fp.FilePickerResult? result;
    try {
      result = await fp.FilePicker.pickFiles(
        type: fp.FileType.image,
        withData: true,
      );
    } catch (_) {
      return;
    }
    final bytes = result?.files.firstOrNull?.bytes;
    if (bytes == null || !mounted) return;

    AvatarStyle selected = AvatarStyle.pixel;
    final previews = <AvatarStyle, Uint8List?>{};
    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
            final fgc = isDark ? Colors.white : Colors.black;

            // One preview per style, cached for the sheet's lifetime, so
            // switching styles is instant after the first render.
            if (!previews.containsKey(selected)) {
              previews[selected] = null;
              processAvatar(bytes, selected).then((out) {
                if (sheetContext.mounted) {
                  setSheetState(() => previews[selected] = out);
                }
              });
            }
            final preview = previews[selected];

            Future<void> save() async {
              setSheetState(() => isSaving = true);
              try {
                await ref
                    .read(profileProvider.notifier)
                    .uploadCustomAvatar(bytes, selected);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile photo updated.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                setSheetState(() => isSaving = false);
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Could not save photo: ${e.toString().replaceAll('StateError: ', '').replaceAll('Exception: ', '')}',
                      ),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            }

            Widget styleChip(AvatarStyle style, String label) {
              final isSel = selected == style;
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: isSel,
                  label: label,
                  child: GestureDetector(
                    onTap: isSaving
                        ? null
                        : () => setSheetState(() => selected = style),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isSel ? fgc : Colors.transparent,
                        border: Border.all(
                          color: fgc.withValues(alpha: isSel ? 1.0 : 0.2),
                          width: 0.75,
                        ),
                        borderRadius: BorderRadius.circular(NoSusTheme.r12),
                      ),
                      child: ExcludeSemantics(
                        child: Center(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: isSel
                                  ? (isDark ? Colors.black : Colors.white)
                                  : fgc.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'CHOOSE YOUR STYLE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                      color: fgc,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: fgc.withValues(alpha: 0.15)),
                      ),
                      child: ClipOval(
                        child: preview == null
                            ? Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: fgc,
                                  ),
                                ),
                              )
                            : Image.memory(
                                preview,
                                key: ValueKey(selected),
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      styleChip(AvatarStyle.pixel, 'PIXEL B/W'),
                      styleChip(AvatarStyle.noir, 'NOIR'),
                      styleChip(AvatarStyle.original, 'ORIGINAL'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selected == AvatarStyle.pixel
                        ? 'Dithered 1-bit pixel art — the NO SUS look.'
                        : selected == AvatarStyle.noir
                        ? 'Black & white photograph.'
                        : 'Your photo, full colour.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: fgc.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: isSaving || preview == null ? null : save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: fgc,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(NoSusTheme.r12),
                      ),
                    ),
                    child: isSaving
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isDark ? Colors.black : Colors.white,
                            ),
                          )
                        : const Text(
                            'USE THIS PHOTO',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              fontSize: 11,
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openAvatarPicker(ProfileData profile) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        final fg = isDark ? Colors.white : Colors.black;

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'CHOOSE AVATAR',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  color: fg,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _pickAndStylePhoto();
                },
                icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                label: const Text(
                  'UPLOAD YOUR PHOTO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: fg,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(
                    color: fg.withValues(alpha: 0.25),
                    width: 0.75,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(NoSusTheme.r12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'OR PICK A CHARACTER',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: fg.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: _avatarPresets.length,
                  itemBuilder: (context, idx) {
                    final item = _avatarPresets[idx];
                    final isSelected = profile.avatarId == item['id'];

                    return Semantics(
                      button: true,
                      selected: isSelected,
                      label: '${item['name']} avatar',
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _saveProfileChanges(
                            profile.displayName,
                            item['id']!,
                            false,
                          );
                          Navigator.of(sheetContext).pop();
                        },
                        child: ExcludeSemantics(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                NoSusTheme.r16,
                              ),
                              border: Border.all(
                                color: isSelected
                                    ? fg
                                    : fg.withValues(alpha: 0.15),
                                width: isSelected ? 2.0 : 1.0,
                              ),
                              color: const Color(0xFF1A1A1A),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Image.asset(
                                      item['asset']!,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                Text(
                                  item['name']!,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openEditName(ProfileData profile) {
    final controller = TextEditingController(text: profile.displayName);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        final fg = isDark ? Colors.white : Colors.black;

        void submit() {
          final newName = controller.text.trim();
          if (newName.isNotEmpty) {
            _saveProfileChanges(newName, profile.avatarId, profile.isCustom);
          }
          Navigator.pop(sheetContext);
        }

        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'EDIT DISPLAY NAME',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  color: fg,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Other members of your groups see this, and so does the activity log.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.5,
                  color: fg.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => submit(),
                style: TextStyle(color: fg, fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'DISPLAY NAME',
                  labelStyle: TextStyle(
                    color: fg.withValues(alpha: 0.5),
                    fontSize: 10,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: fg,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(NoSusTheme.r12),
                  ),
                ),
                child: const Text(
                  'SAVE',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = theme.colorScheme.onSurface;
    final subtle = fg.withValues(alpha: 0.55);
    final user = ref.watch(authStateProvider).value;
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'PROFILE',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            fontSize: 13,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: fg)),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(NoSusTheme.s32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 40,
                ),
                const SizedBox(height: NoSusTheme.s16),
                Text(
                  'Could not load your profile.',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: NoSusTheme.s8),
                Text(
                  'Check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: subtle, height: 1.5),
                ),
                const SizedBox(height: NoSusTheme.s24),
                FilledButton(
                  onPressed: () => ref.invalidate(profileProvider),
                  child: const Text('RETRY', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
        ),
        data: (profile) {
          final groups =
              ref.watch(groupsProvider).value ?? const <StudyGroup>[];
          final adminOf = groups
              .where((g) => g.members.any((m) => m.id == user?.id && m.isAdmin))
              .length;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                physics: NoSusTheme.getScrollPhysics(context),
                padding: const EdgeInsets.fromLTRB(
                  NoSusTheme.s24,
                  NoSusTheme.s8,
                  NoSusTheme.s24,
                  NoSusTheme.s32,
                ),
                children: [
                  // ── Identity ───────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: NoSusTheme.cardDecoration(context),
                    child: Row(
                      children: [
                        Semantics(
                          button: true,
                          label: 'Change avatar',
                          child: GestureDetector(
                            onTap: () => _openAvatarPicker(profile),
                            child: ExcludeSemantics(
                              child: Stack(
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF1A1A1A),
                                      border: Border.all(
                                        color: fg.withValues(alpha: 0.1),
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: ProfileAvatar(
                                        profile: profile,
                                        size: 80,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: fg,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.camera_alt,
                                        size: 10,
                                        color: isDark
                                            ? Colors.black
                                            : Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      profile.displayName,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.2,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _openEditName(profile),
                                    tooltip: 'Edit display name',
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                      color: subtle,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              GestureDetector(
                                onTap: _handleEmailTap,
                                child: Text(
                                  user?.email ?? '—',
                                  style: TextStyle(color: subtle, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const _VerificationBadge(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 250.ms),

                  const SizedBox(height: NoSusTheme.s24),

                  // ── Communities ────────────────────────────────────────────
                  Row(
                    children: [
                      Text(
                        'YOUR COMMUNITIES',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: fg.withValues(alpha: 0.4),
                          fontSize: 10,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const Spacer(),
                      const WhatsThisButton(
                        topicId: HelpCatalog.roles,
                        semanticLabel: 'What can admins do?',
                      ),
                    ],
                  ),
                  const SizedBox(height: NoSusTheme.s8),
                  if (groups.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: NoSusTheme.cardDecoration(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Not in any groups yet',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Groups are where shared documents live. Join one with an '
                            'invite, or create your own from the Groups tab.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: subtle,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    Container(
                      decoration: NoSusTheme.cardDecoration(context),
                      // Transparent Material between card and rows so each
                      // group row's ink splash paints over the decoration
                      // instead of being hidden by it.
                      child: Material(
                        type: MaterialType.transparency,
                        borderRadius: BorderRadius.circular(NoSusTheme.r16),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (var i = 0; i < groups.length; i++) ...[
                              if (i > 0)
                                Divider(
                                  height: 1,
                                  thickness: 0.5,
                                  color: fg.withValues(alpha: 0.08),
                                ),
                              _GroupRow(
                                group: groups[i],
                                isAdmin: groups[i].members.any(
                                  (m) => m.id == user?.id && m.isAdmin,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: NoSusTheme.s8),
                    Text(
                      adminOf == 0
                          ? 'Member of ${groups.length} '
                                '${groups.length == 1 ? 'group' : 'groups'}.'
                          : 'Member of ${groups.length} '
                                '${groups.length == 1 ? 'group' : 'groups'}, '
                                'admin of $adminOf.',
                      style: TextStyle(fontSize: 11, color: subtle),
                    ),
                  ],

                  const SizedBox(height: NoSusTheme.s24),

                  // Settings is a separate screen; this is the discoverable
                  // route to it besides the app-bar icon.
                  Container(
                    decoration: NoSusTheme.cardDecoration(context),
                    // Transparent Material so the tap ripple paints over the
                    // card decoration rather than being hidden beneath it.
                    child: Material(
                      type: MaterialType.transparency,
                      borderRadius: BorderRadius.circular(NoSusTheme.r16),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: Icon(
                          Icons.settings_outlined,
                          size: 18,
                          color: fg,
                        ),
                        title: const Text(
                          'Settings',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Notifications, privacy, help, and account controls',
                          style: TextStyle(color: subtle, fontSize: 10),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: subtle,
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 120.ms, duration: 250.ms),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Real verification state, not decoration.
class _VerificationBadge extends StatelessWidget {
  const _VerificationBadge();

  @override
  Widget build(BuildContext context) {
    final isVerified =
        SupabaseService.instance.isReachable &&
        Supabase.instance.client.auth.currentUser?.emailConfirmedAt != null;
    final color = isVerified ? Colors.green : Colors.amber;

    return Semantics(
      label: isVerified ? 'Email verified' : 'Email not yet verified',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: color.withValues(alpha: 0.25),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isVerified
                    ? Icons.verified_user_outlined
                    : Icons.mark_email_unread_outlined,
                color: color,
                size: 10,
              ),
              const SizedBox(width: 4),
              Text(
                isVerified ? 'EMAIL VERIFIED' : 'EMAIL UNVERIFIED',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  final StudyGroup group;
  final bool isAdmin;

  const _GroupRow({required this.group, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;
    final subtle = fg.withValues(alpha: 0.55);

    return ListTile(
      leading: Icon(
        isAdmin ? Icons.shield_outlined : Icons.group_outlined,
        size: 18,
        color: fg,
      ),
      title: Text(
        group.name,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        isAdmin
            ? 'Admin · ${group.members.length} '
                  '${group.members.length == 1 ? 'member' : 'members'}'
            : 'Member · ${group.members.length} '
                  '${group.members.length == 1 ? 'member' : 'members'}',
        style: TextStyle(color: subtle, fontSize: 10),
      ),
      trailing: Icon(Icons.chevron_right, size: 16, color: subtle),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => GroupDetailScreen(group: group)),
      ),
    );
  }
}
