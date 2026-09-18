import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/supabase_share_repository.dart';
import '../../data/share_fetch_client.dart';
import '../../domain/entities/share_link.dart';
import '../../domain/repositories/share_repository.dart';

/// Repository singleton for creating/managing SecureSend share links.
/// (The anonymous viewing path never uses this — see [ShareFetchClient].)
final shareRepositoryProvider = Provider<ShareRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseShareRepository(client, ShareFetchClient.instance);
});

class ShareAnalytics {
  final List<ShareViewEvent> events;
  final int totalViews;
  final int uniqueViewers;
  final int liveCount;

  const ShareAnalytics({
    required this.events,
    required this.totalViews,
    required this.uniqueViewers,
    required this.liveCount,
  });
}

/// Provides realtime views/analytics for a specific share link ID.
final shareAnalyticsProvider = StreamProvider.family<ShareAnalytics, String>((ref, linkId) {
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('share_view_events')
      .stream(primaryKey: ['id'])
      .eq('link_id', linkId)
      .order('started_at', ascending: false)
      .map((rows) {
        final events = rows.map((row) => ShareViewEvent.fromMap(row)).toList();
        final totalViews = events.length;
        
        final uniqueEmails = events.map((e) => e.viewerEmail).toSet();
        final uniqueViewers = uniqueEmails.length;
        
        final liveCount = events.where((e) => e.isLive).length;

        return ShareAnalytics(
          events: events,
          totalViews: totalViews,
          uniqueViewers: uniqueViewers,
          liveCount: liveCount,
        );
      });
});

/// Raw stream of all share view events for current user's links
final shareNotificationStreamProvider = StreamProvider<List<ShareViewEvent>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  
  return client
      .from('share_view_events')
      .stream(primaryKey: ['id'])
      .order('started_at', ascending: false)
      .map((rows) => rows.map((row) => ShareViewEvent.fromMap(row)).toList());
});

class ShareNotificationState {
  final ShareViewEvent? latestEvent;
  final String? fileName;
  const ShareNotificationState({this.latestEvent, this.fileName});
}

class ShareNotificationNotifier extends Notifier<ShareNotificationState> {
  final Set<String> _seenEventIds = {};

  @override
  ShareNotificationState build() {
    ref.listen<AsyncValue<List<ShareViewEvent>>>(shareNotificationStreamProvider, (prev, next) {
      if (next.hasValue) {
        // Deferred off Riverpod's callback stack. checkNewEvents reads a
        // provider and runs synchronously up to its first await, so calling it
        // straight from this listener trips the "cannot use Ref inside
        // life-cycles" assert. The read stays lazy so it keeps degrading
        // gracefully when Supabase is unreachable.
        Future.microtask(() => checkNewEvents(next.value!));
      }
    });
    return const ShareNotificationState();
  }

  void checkNewEvents(List<ShareViewEvent> events) async {
    if (events.isEmpty) return;
    
    final newest = events.first;
    if (_seenEventIds.contains(newest.id)) return;
    
    _seenEventIds.add(newest.id);

    // If it started more than 15 seconds ago, it's not a fresh view (e.g. initial load of list)
    if (DateTime.now().difference(newest.startedAt).inSeconds > 15) return;

    try {
      final client = ref.read(supabaseClientProvider);
      final res = await client
          .from('share_links')
          .select('secure_files(name)')
          .eq('id', newest.linkId)
          .maybeSingle();
      
      final fileName = (res?['secure_files'] as Map?)?['name'] as String? ?? 'a file';
      
      state = ShareNotificationState(latestEvent: newest, fileName: fileName);
    } catch (_) {
      state = ShareNotificationState(latestEvent: newest, fileName: 'a file');
    }
  }
  
  void dismiss() {
    state = const ShareNotificationState();
  }
}

/// Provides real-time banner notifications when a user's link is opened.
final shareNotificationProvider = NotifierProvider<ShareNotificationNotifier, ShareNotificationState>(() {
  return ShareNotificationNotifier();
});

