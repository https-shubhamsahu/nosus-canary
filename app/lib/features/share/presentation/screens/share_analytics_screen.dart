import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/share_link.dart';
import '../providers/share_providers.dart';

class ShareAnalyticsScreen extends ConsumerWidget {
  const ShareAnalyticsScreen({
    super.key,
    required this.linkId,
    required this.fileName,
  });

  final String linkId;
  final String fileName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(shareAnalyticsProvider(linkId));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fileName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            const Text(
              'DOCUMENT INTELLIGENCE',
              style: TextStyle(
                fontSize: 9,
                color: Colors.blueAccent,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
            tooltip: 'REVOKE LINK',
            onPressed: () => _confirmRevocation(context, ref),
          ),
        ],
      ),
      body: analyticsAsync.when(
        data: (data) => _buildContent(context, ref, data),
        loading: () => const Center(
          child: CircularProgressIndicator(strokeWidth: 2.0),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Failed to load analytics: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, ShareAnalytics data) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Stats Overview Row
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('TOTAL VIEWS', '${data.totalViews}'),
              _buildStatItem('UNIQUE VIEWERS', '${data.uniqueViewers}'),
              _buildStatItem(
                'LIVE NOW',
                '${data.liveCount}',
                isLive: data.liveCount > 0,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // List Header
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RECENT VIEWS',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontSize: 10,
                  letterSpacing: 1.0,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              if (data.liveCount > 0)
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'REAL-TIME UPDATING',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontSize: 9,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        // Views List
        Expanded(
          child: data.events.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.track_changes_outlined,
                        size: 32,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No views recorded yet.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: data.events.length,
                  separatorBuilder: (_, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final event = data.events[index];
                    return _buildEventTile(context, event);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, {bool isLive = false}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: Colors.grey, letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLive) ...[
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: isLive ? Colors.green : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEventTile(BuildContext context, ShareViewEvent event) {
    final theme = Theme.of(context);
    final isLive = event.isLive;
    
    // Format duration
    String durationText;
    if (event.durationSeconds < 60) {
      durationText = '${event.durationSeconds}s';
    } else {
      final min = event.durationSeconds ~/ 60;
      final sec = event.durationSeconds % 60;
      durationText = '${min}m ${sec}s';
    }

    // Format time ago
    final diff = DateTime.now().difference(event.startedAt);
    String timeAgo;
    if (diff.inMinutes < 1) {
      timeAgo = 'just now';
    } else if (diff.inHours < 1) {
      timeAgo = '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      timeAgo = '${diff.inHours}h ago';
    } else {
      timeAgo = '${diff.inDays}d ago';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Left Status Indicator/Device Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isLive
                  ? Colors.green.withValues(alpha: 0.1)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              event.deviceType == 'app' ? Icons.phone_android : Icons.language,
              size: 16,
              color: isLive ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(width: 14),
          // Email & Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.viewerEmail,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isLive) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          border: Border.all(color: Colors.green, width: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '● LIVE',
                          style: TextStyle(color: Colors.green, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      timeAgo,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    const Text('•', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(width: 8),
                    Text(
                      'Viewed for $durationText',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRevocation(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('REVOKE LINK', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will permanently disable this share link. Anyone trying to open it will be blocked. Are you sure?',
          style: TextStyle(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontSize: 11)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('REVOKE', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(shareRepositoryProvider).revokeLink(linkId);
        if (!context.mounted) return;
        Navigator.pop(context); // Close analytics screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link revoked successfully.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to revoke link: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
