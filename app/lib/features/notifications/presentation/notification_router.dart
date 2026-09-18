import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../main.dart' show activeTabProvider;
import '../../groups/domain/models/study_group.dart';
import '../../groups/providers/groups_provider.dart';
import '../../groups/screens/group_detail_screen.dart';

/// Turns a notification's `deep_link` into navigation.
///
/// Deep links are opaque in-app routes (`group:<id>`, `groups`, `audit`) rather
/// than URLs. Notifications travel through a third-party push provider and land
/// on lock screens, so nothing here may carry a token, key or file name — the
/// id is resolved against the database, behind RLS, after the app is open.
///
/// Every path handles the resource having gone away. A notification outlives
/// what it points at more often than not: groups get deleted, access gets
/// revoked, and "you were removed from a group" is *by definition* a link to
/// something the recipient can no longer open.
abstract final class NotificationRouter {
  static Future<void> open(
    BuildContext context,
    WidgetRef ref,
    String? deepLink,
  ) async {
    if (deepLink == null || deepLink.isEmpty) return;

    if (deepLink == 'groups') {
      ref.read(activeTabProvider.notifier).changeTab(4);
      return;
    }

    if (deepLink == 'audit') {
      ref.read(activeTabProvider.notifier).changeTab(3);
      return;
    }

    if (deepLink.startsWith('group:')) {
      final groupId = deepLink.substring('group:'.length);
      if (groupId.isEmpty) return;

      // Resolve from the already-loaded list rather than fetching: if the group
      // is not in it, the user is not a member any more, which is exactly the
      // case that must not open a detail screen.
      final groups = ref.read(groupsProvider).value ?? const <StudyGroup>[];
      StudyGroup? match;
      for (final g in groups) {
        if (g.id == groupId) {
          match = g;
          break;
        }
      }

      if (match == null) {
        _showGone(
          context,
          'That group is no longer available to you. It may have been deleted, '
          'or your access may have been removed.',
        );
        ref.read(activeTabProvider.notifier).changeTab(4);
        return;
      }

      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => GroupDetailScreen(group: match!)),
      );
      return;
    }

    // Unknown scheme: a notification from a newer build than this client. Land
    // somewhere sensible instead of doing nothing, which reads as a broken tap.
    ref.read(activeTabProvider.notifier).changeTab(0);
  }

  static void _showGone(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }
}
