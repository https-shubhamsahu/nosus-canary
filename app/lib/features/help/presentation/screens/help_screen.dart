import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme.dart';
import '../../domain/help_topic.dart';
import '../../../onboarding/presentation/providers/tour_providers.dart';
import 'help_topic_screen.dart';

/// Searchable Help centre.
///
/// Works signed out — it is reachable from the welcome surface, and a confused
/// user often cannot get past the thing they are confused by. Nothing here
/// reads Supabase.
class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _replayTour() async {
    await ref.read(tourProgressProvider.notifier).resetAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Tips reset. They will appear again as you move around the app.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    final subtle = fg.withValues(alpha: 0.6);
    final results = HelpCatalog.search(_query);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'HELP',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            fontSize: 13,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: NoSusTheme.s24,
                    vertical: NoSusTheme.s8,
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    style: TextStyle(fontSize: 14, color: fg),
                    cursorColor: fg,
                    decoration: InputDecoration(
                      hintText: 'Search help',
                      hintStyle: TextStyle(fontSize: 14, color: subtle),
                      prefixIcon: Icon(Icons.search, size: 18, color: subtle),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(NoSusTheme.r12),
                        borderSide: BorderSide(
                          color: fg.withValues(alpha: 0.12),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(NoSusTheme.r12),
                        borderSide: BorderSide(
                          color: fg.withValues(alpha: 0.12),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(NoSusTheme.r12),
                        borderSide: BorderSide(color: fg),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: results.isEmpty
                      ? _NoResults(query: _query)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            NoSusTheme.s24,
                            NoSusTheme.s8,
                            NoSusTheme.s24,
                            NoSusTheme.s32,
                          ),
                          physics: NoSusTheme.getScrollPhysics(context),
                          itemCount: results.length + 1,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: NoSusTheme.s12),
                          itemBuilder: (context, i) {
                            if (i == results.length) {
                              return _ReplayTourTile(onTap: _replayTour);
                            }
                            return _TopicTile(topic: results[i]);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  final HelpTopic topic;
  const _TopicTile({required this.topic});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;

    return Semantics(
      button: true,
      label: '${topic.title}. ${topic.summary}',
      child: InkWell(
        borderRadius: BorderRadius.circular(NoSusTheme.r16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => HelpTopicScreen(topicId: topic.id)),
        ),
        child: Container(
          padding: const EdgeInsets.all(NoSusTheme.s16),
          decoration: NoSusTheme.cardDecoration(context),
          child: ExcludeSemantics(
            child: Row(
              children: [
                Icon(topic.icon, size: 20, color: fg.withValues(alpha: 0.8)),
                const SizedBox(width: NoSusTheme.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic.title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        topic.summary,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: fg.withValues(alpha: 0.55),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: NoSusTheme.s8),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: fg.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReplayTourTile extends StatelessWidget {
  final VoidCallback onTap;
  const _ReplayTourTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(top: NoSusTheme.s16),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.restart_alt, size: 16),
        label: const Text(
          'SHOW THE IN-APP TIPS AGAIN',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: fg.withValues(alpha: 0.25), width: 0.75),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NoSusTheme.r12),
          ),
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  final String query;
  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtle = theme.colorScheme.onSurface.withValues(alpha: 0.5);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NoSusTheme.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_outlined, size: 40, color: subtle),
            const SizedBox(height: NoSusTheme.s16),
            Text(
              'Nothing matches "$query"',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: NoSusTheme.s8),
            Text(
              'Try a shorter word — "invite", "burn", "watermark", "admin".',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: subtle, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
