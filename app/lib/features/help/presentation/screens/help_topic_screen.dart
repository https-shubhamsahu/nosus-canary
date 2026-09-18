import 'package:flutter/material.dart';

import '../../../../theme.dart';
import '../../domain/help_topic.dart';

/// A single help topic. Reached from the Help list or from a contextual
/// "What's this?" button next to the feature it explains.
class HelpTopicScreen extends StatelessWidget {
  final String topicId;

  const HelpTopicScreen({super.key, required this.topicId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    final topic = HelpCatalog.byId(topicId);

    if (topic == null) {
      // Only reachable if a caller passes an id that no longer exists, i.e. a
      // renamed topic. Fail visibly rather than showing an empty page.
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'HELP',
            style: TextStyle(fontSize: 13, letterSpacing: 2),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(NoSusTheme.s32),
            child: Text(
              'That help topic is no longer available.',
              textAlign: TextAlign.center,
              style: TextStyle(color: fg.withValues(alpha: 0.6), fontSize: 13),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          topic.title.toUpperCase(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            fontSize: 12,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      topic.icon,
                      size: 26,
                      color: fg.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: NoSusTheme.s16),
                    Expanded(
                      child: Text(
                        topic.summary,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: 15,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: NoSusTheme.s24),
                for (final section in topic.sections) ...[
                  _SectionBlock(section: section),
                  const SizedBox(height: NoSusTheme.s16),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  final HelpSection section;
  const _SectionBlock({required this.section});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    final caution = section.isCaution;
    // Amber rather than red: these are boundaries of the product's protection,
    // which the user needs to read, not errors they need to panic about.
    final accent = caution ? Colors.amber : fg;

    return Container(
      padding: const EdgeInsets.all(NoSusTheme.s16),
      decoration: caution
          ? BoxDecoration(
              color: accent.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(NoSusTheme.r16),
              border: Border.all(
                color: accent.withValues(alpha: 0.3),
                width: 0.75,
              ),
            )
          : NoSusTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (caution) ...[
                Icon(Icons.info_outline, size: 14, color: accent),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  section.heading,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    color: caution ? accent : fg.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: NoSusTheme.s8),
          Text(
            section.body,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              height: 1.65,
              color: fg.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small "?" affordance to drop next to a control whose purpose is not obvious
/// from its label. Opens the matching help topic rather than a bespoke tooltip,
/// so the explanation stays in one place.
class WhatsThisButton extends StatelessWidget {
  final String topicId;

  /// Announced to screen readers, which cannot infer meaning from a "?" glyph.
  final String semanticLabel;

  const WhatsThisButton({
    super.key,
    required this.topicId,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;
    return IconButton(
      icon: Icon(
        Icons.help_outline,
        size: 16,
        color: fg.withValues(alpha: 0.45),
      ),
      tooltip: semanticLabel,
      visualDensity: VisualDensity.compact,
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => HelpTopicScreen(topicId: topicId)),
      ),
    );
  }
}
