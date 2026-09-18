import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/features/notifications/domain/app_notification.dart';

/// The wire names here are column names on `notification_preferences` and
/// values of the CHECK constraint on `notifications.category`
/// (20260730112523_notifications.sql). A mismatch does not fail loudly — it
/// silently stops delivering a category — so it is pinned.
void main() {
  group('NotificationCategory', () {
    test('wire names match the database schema exactly', () {
      expect(NotificationCategory.values.map((c) => c.wireName).toSet(), {
        'invites',
        'membership',
        'documents',
        'security',
      });
    });

    test('round-trips through fromWire', () {
      for (final category in NotificationCategory.values) {
        expect(NotificationCategory.fromWire(category.wireName), category);
      }
    });

    test('an unknown category from a newer build resolves to null', () {
      expect(NotificationCategory.fromWire('somethingNew'), isNull);
      expect(NotificationCategory.fromWire(null), isNull);
    });

    test('security is the only category flagged critical', () {
      expect(NotificationCategory.values.where((c) => c.isCritical).toList(), [
        NotificationCategory.security,
      ]);
    });

    test('every category has user-facing copy', () {
      for (final category in NotificationCategory.values) {
        expect(category.label.trim(), isNotEmpty);
        expect(category.description.trim(), isNotEmpty);
      }
    });
  });

  group('AppNotification.fromRow', () {
    test('parses a full row', () {
      final n = AppNotification.fromRow({
        'id': 'n1',
        'category': 'documents',
        'title': 'New document',
        'body': 'A document was shared in one of your groups.',
        'deep_link': 'group:g1',
        'group_id': 'g1',
        'created_at': '2026-07-27T10:00:00Z',
        'read_at': null,
      });

      expect(n.id, 'n1');
      expect(n.category, NotificationCategory.documents);
      expect(n.deepLink, 'group:g1');
      expect(n.isUnread, isTrue);
    });

    test('a row with read_at set is not unread', () {
      final n = AppNotification.fromRow({
        'id': 'n2',
        'category': 'security',
        'title': 'Access revoked',
        'body': 'Your access to a group changed.',
        'created_at': '2026-07-27T10:00:00Z',
        'read_at': '2026-07-27T11:00:00Z',
      });

      expect(n.isUnread, isFalse);
    });

    test('an unrecognised category falls back rather than throwing', () {
      // A newer server build could enqueue a category this client predates.
      // Showing it under a known heading beats crashing the inbox.
      final n = AppNotification.fromRow({
        'id': 'n3',
        'category': 'somethingNew',
        'title': 'Something happened',
        'body': '',
        'created_at': '2026-07-27T10:00:00Z',
      });

      expect(n.category, NotificationCategory.membership);
    });

    test('a malformed timestamp does not throw', () {
      final n = AppNotification.fromRow({
        'id': 'n4',
        'category': 'invites',
        'title': 'Invite',
        'body': '',
        'created_at': 'not-a-date',
      });

      expect(n.createdAt.millisecondsSinceEpoch, 0);
    });
  });

  group('NotificationPreferences', () {
    test('defaults to everything on, matching the column defaults', () {
      for (final category in NotificationCategory.values) {
        expect(NotificationPreferences.allOn.isEnabled(category), isTrue);
      }
    });

    test('an absent column reads as enabled, not disabled', () {
      // enqueue_notification treats "no preference row" as on. A client that
      // defaulted the other way would show the user muted categories that are
      // in fact delivering.
      final prefs = NotificationPreferences.fromRow({'invites': false});
      expect(prefs.isEnabled(NotificationCategory.invites), isFalse);
      expect(prefs.isEnabled(NotificationCategory.security), isTrue);
    });

    test('withCategory changes one flag and leaves the rest alone', () {
      final updated = NotificationPreferences.allOn.withCategory(
        NotificationCategory.documents,
        false,
      );

      expect(updated.isEnabled(NotificationCategory.documents), isFalse);
      expect(updated.isEnabled(NotificationCategory.invites), isTrue);
      expect(
        NotificationPreferences.allOn.isEnabled(NotificationCategory.documents),
        isTrue,
        reason: 'the original must not be mutated',
      );
    });

    test('toColumns emits exactly the schema column names', () {
      expect(NotificationPreferences.allOn.toColumns().keys.toSet(), {
        'invites',
        'membership',
        'documents',
        'security',
      });
    });
  });
}
