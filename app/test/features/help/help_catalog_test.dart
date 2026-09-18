import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/features/help/domain/help_topic.dart';

/// Help is the surface a confused user reaches for, and every contextual
/// "What's this?" button deep-links into it by id. A renamed or removed topic
/// turns those buttons into dead ends, which is exactly the failure the Help
/// centre exists to prevent — so the ids are pinned here.
void main() {
  group('HelpCatalog', () {
    test('every id constant resolves to a topic', () {
      const ids = [
        HelpCatalog.whatIsNoSus,
        HelpCatalog.groups,
        HelpCatalog.roles,
        HelpCatalog.secureDocuments,
        HelpCatalog.watermarking,
        HelpCatalog.burnNotes,
        HelpCatalog.burnFiles,
        HelpCatalog.shareLinks,
        HelpCatalog.auditLog,
        HelpCatalog.notifications,
        HelpCatalog.account,
        HelpCatalog.troubleshooting,
      ];

      for (final id in ids) {
        expect(
          HelpCatalog.byId(id),
          isNotNull,
          reason: 'a WhatsThisButton points at "$id"',
        );
      }
    });

    test('topic ids are unique', () {
      final ids = HelpCatalog.topics.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every topic has a summary and at least one section', () {
      for (final topic in HelpCatalog.topics) {
        expect(topic.summary.trim(), isNotEmpty, reason: topic.id);
        expect(topic.sections, isNotEmpty, reason: topic.id);
        for (final section in topic.sections) {
          expect(section.heading.trim(), isNotEmpty, reason: topic.id);
          expect(section.body.trim(), isNotEmpty, reason: topic.id);
        }
      }
    });

    test('an unknown id resolves to null rather than throwing', () {
      expect(HelpCatalog.byId('no-such-topic'), isNull);
    });

    group('search', () {
      test('an empty query returns everything', () {
        expect(HelpCatalog.search('  ').length, HelpCatalog.topics.length);
      });

      test('matches on body text, not just titles', () {
        // Watermark is a real product concept; retired experiments are absent.
        final results = HelpCatalog.search('watermark');
        expect(results, isNotEmpty);
        expect(results.map((t) => t.id), contains(HelpCatalog.watermarking));
      });

      test('matches on keywords that never appear in the visible copy', () {
        // Someone searching the symptom, not the feature name.
        final results = HelpCatalog.search('expired');
        expect(results.map((t) => t.id), contains(HelpCatalog.troubleshooting));
      });

      test('is case insensitive', () {
        expect(HelpCatalog.search('BURN'), isNotEmpty);
      });

      test('a query matching nothing returns empty rather than everything', () {
        expect(HelpCatalog.search('zzzznotathing'), isEmpty);
      });
    });

    test('screenshot-blocking copy stays scoped to Android', () {
      // PROJECT_CONSTITUTION.md §2.3: copy must never outrun the actual
      // capability. ScreenshotGuard returns early on web and iOS, so any claim
      // that screenshots are blocked has to say where.
      final topic = HelpCatalog.byId(HelpCatalog.watermarking)!;
      final cautions = topic.sections.where((s) => s.isCaution).toList();
      expect(
        cautions,
        isNotEmpty,
        reason: 'the limits of screenshot blocking must be called out',
      );
      expect(
        cautions.any((s) => s.body.contains('Android')),
        isTrue,
        reason: 'the platform scope of screenshot blocking must be explicit',
      );
    });
  });
}
