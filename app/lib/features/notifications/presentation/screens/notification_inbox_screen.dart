import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../components/async_state_view.dart';
import '../../../../components/shimmer_box.dart';
import '../../../../core/mascot/mascot_state.dart';
import '../../../../core/mascot/mascot_view.dart';
import '../../../../theme.dart';
import '../../../help/domain/help_topic.dart';
import '../../../help/presentation/screens/help_topic_screen.dart';
import '../../domain/app_notification.dart';
import '../notification_router.dart';
import '../providers/notification_providers.dart';

/// The in-app notification inbox.
///
/// Reads the same `notifications` rows push delivery would send, so it is the
/// complete record whether or not FCM is configured — which today it is not.
/// Someone who declined the OS permission, or is on the web build, loses
/// nothing except the interruption.
class NotificationInboxScreen extends ConsumerWidget {
  const NotificationInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    final subtle = fg.withValues(alpha: 0.6);
    final inbox = ref.watch(notificationInboxProvider);
    final unread = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'NOTIFICATIONS',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            fontSize: 13,
          ),
        ),
        centerTitle: true,
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(notificationRepositoryProvider).markRead();
              },
              child: Text(
                'MARK ALL READ',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: subtle,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: AsyncStateView<List<AppNotification>>(
              value: inbox,
              onRetry: () => ref.invalidate(notificationInboxProvider),
              errorMessage: 'Could not load your notifications',
              loading: (context) => Padding(
                padding: const EdgeInsets.all(NoSusTheme.s24),
                child: ShimmerListSkeleton(
                  spacing: NoSusTheme.s12,
                  itemBuilder: (context) => const _NotificationSkeleton(),
                ),
              ),
              isEmpty: (items) => items.isEmpty,
              empty: (context) => const _EmptyInbox(),
              data: (context, items) => ListView.separated(
                physics: NoSusTheme.getScrollPhysics(context),
                padding: const EdgeInsets.all(NoSusTheme.s24),
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: NoSusTheme.s12),
                itemBuilder: (context, i) =>
                    _NotificationRow(notification: items[i], index: i),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationRow extends ConsumerWidget {
  final AppNotification notification;
  final int index;

  const _NotificationRow({required this.notification, required this.index});

  IconData get _icon => switch (notification.category) {
    NotificationCategory.invites => Icons.mail_outline,
    NotificationCategory.membership => Icons.group_outlined,
    NotificationCategory.documents => Icons.description_outlined,
    NotificationCategory.security => Icons.gpp_maybe_outlined,
  };

  String _relativeTime() {
    final diff = DateTime.now().difference(notification.createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final d = notification.createdAt;
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    final subtle = fg.withValues(alpha: 0.6);
    final isUnread = notification.isUnread;

    return Dismissible(
          key: ValueKey(notification.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(NoSusTheme.r16),
            ),
            child: const Icon(
              Icons.delete_outline,
              color: Colors.redAccent,
              size: 20,
            ),
          ),
          onDismissed: (_) {
            ref.read(notificationRepositoryProvider).delete(notification.id);
          },
          child: Semantics(
            button: true,
            label:
                '${notification.title}. ${notification.body}. '
                '${_relativeTime()}.${isUnread ? ' Unread.' : ''}',
            child: InkWell(
              borderRadius: BorderRadius.circular(NoSusTheme.r16),
              onTap: () async {
                HapticFeedback.selectionClick();
                // Read first: if the destination is gone, the user has still seen
                // it, and leaving it unread would make the badge unclearable.
                await ref
                    .read(notificationRepositoryProvider)
                    .markRead(ids: [notification.id]);
                if (!context.mounted) return;
                await NotificationRouter.open(
                  context,
                  ref,
                  notification.deepLink,
                );
              },
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isUnread ? fg.withValues(alpha: 0.04) : null,
                  borderRadius: BorderRadius.circular(NoSusTheme.r16),
                  border: Border.all(
                    color: fg.withValues(alpha: isUnread ? 0.18 : 0.08),
                    width: 0.75,
                  ),
                ),
                child: ExcludeSemantics(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(_icon, size: 18, color: fg.withValues(alpha: 0.75)),
                      const SizedBox(width: NoSusTheme.s16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    notification.title,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontSize: 13.5,
                                      fontWeight: isUnread
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                                // Unread is carried by weight and a dot, not by
                                // colour alone.
                                if (isUnread)
                                  Container(
                                    width: 7,
                                    height: 7,
                                    margin: const EdgeInsets.only(left: 8),
                                    decoration: BoxDecoration(
                                      color: fg,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              notification.body,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: subtle,
                                fontSize: 12.5,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _relativeTime().toUpperCase(),
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontSize: 9,
                                letterSpacing: 1.0,
                                color: subtle.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        )
        .animate(delay: (index.clamp(0, 8) * 40).ms)
        .fadeIn(duration: 220.ms)
        .slideY(begin: 0.03, end: 0);
  }
}

/// Empty state as an explanation, not a dead end — it says what would appear
/// here and where the switches are.
class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtle = theme.colorScheme.onSurface.withValues(alpha: 0.55);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NoSusTheme.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MascotView(
              character: MascotCharacter.lux,
              size: 48,
              fallback: Icon(Icons.notifications_none, size: 48, color: subtle),
            ),
            const SizedBox(height: NoSusTheme.s24),
            Text(
              'Nothing yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: NoSusTheme.s8),
            Text(
              'This is where you will hear about invites, changes to your '
              'group membership, new documents, and security alerts.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: subtle,
                fontSize: 13,
                height: 1.6,
              ),
            ),
            const SizedBox(height: NoSusTheme.s16),
            const WhatsThisButton(
              topicId: HelpCatalog.notifications,
              semanticLabel: 'What will I be notified about?',
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 350.ms);
  }
}

class _NotificationSkeleton extends StatelessWidget {
  const _NotificationSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShimmerBox(width: 18, height: 18, radius: 4),
        SizedBox(width: NoSusTheme.s16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(width: 140, height: 13),
              SizedBox(height: 8),
              ShimmerBox(width: 220, height: 11),
            ],
          ),
        ),
      ],
    );
  }
}
