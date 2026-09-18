/// The notification categories a user can switch independently.
///
/// Mirrors the CHECK constraint on `notifications.category` and the boolean
/// columns on `notification_preferences` — see
/// supabase/migrations/20260730112523_notifications.sql. The wire name is the
/// column name; changing one without the other silently stops delivery.
enum NotificationCategory {
  invites(
    'invites',
    'Invites & requests',
    'Someone invited you to a group, or asked to join one you administer.',
  ),
  membership(
    'membership',
    'Membership & roles',
    'You were added or removed from a group, or your role changed.',
  ),
  documents(
    'documents',
    'Document activity',
    'New documents shared in groups you belong to.',
  ),
  security(
    'security',
    'Security alerts',
    'Access revoked, unusual sign-ins, and integrity warnings.',
  );

  final String wireName;
  final String label;
  final String description;

  const NotificationCategory(this.wireName, this.label, this.description);

  static NotificationCategory? fromWire(String? name) {
    for (final c in NotificationCategory.values) {
      if (c.wireName == name) return c;
    }
    return null;
  }

  /// Security alerts are the ones a user would still want after muting
  /// everything else, so the UI warns before switching them off rather than
  /// treating every category as interchangeable.
  bool get isCritical => this == NotificationCategory.security;
}

class AppNotification {
  final String id;
  final NotificationCategory category;
  final String title;
  final String body;

  /// In-app route: `group:<id>`, `groups`, or `audit`. Never a URL, and never
  /// carries key material — see NotificationRouter.
  final String? deepLink;
  final String? groupId;
  final DateTime createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.createdAt,
    this.deepLink,
    this.groupId,
    this.readAt,
  });

  bool get isUnread => readAt == null;

  factory AppNotification.fromRow(Map<String, dynamic> row) {
    return AppNotification(
      id: row['id'] as String,
      category:
          NotificationCategory.fromWire(row['category'] as String?) ??
          NotificationCategory.membership,
      title: row['title'] as String? ?? 'Notification',
      body: row['body'] as String? ?? '',
      deepLink: row['deep_link'] as String?,
      groupId: row['group_id'] as String?,
      createdAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      readAt: DateTime.tryParse(row['read_at']?.toString() ?? '')?.toLocal(),
    );
  }

  AppNotification copyWith({DateTime? readAt}) => AppNotification(
    id: id,
    category: category,
    title: title,
    body: body,
    deepLink: deepLink,
    groupId: groupId,
    createdAt: createdAt,
    readAt: readAt ?? this.readAt,
  );

  @override
  bool operator ==(Object other) =>
      other is AppNotification && other.id == id && other.readAt == readAt;

  @override
  int get hashCode => Object.hash(id, readAt);
}

/// Per-category on/off state for the signed-in account.
class NotificationPreferences {
  final Map<NotificationCategory, bool> enabled;

  const NotificationPreferences(this.enabled);

  /// Matches the column defaults, and is what the enqueue function assumes when
  /// no preferences row exists yet.
  static const NotificationPreferences allOn = NotificationPreferences({
    NotificationCategory.invites: true,
    NotificationCategory.membership: true,
    NotificationCategory.documents: true,
    NotificationCategory.security: true,
  });

  bool isEnabled(NotificationCategory category) => enabled[category] ?? true;

  factory NotificationPreferences.fromRow(Map<String, dynamic> row) {
    return NotificationPreferences({
      for (final c in NotificationCategory.values)
        c: row[c.wireName] as bool? ?? true,
    });
  }

  NotificationPreferences withCategory(
    NotificationCategory category,
    bool value,
  ) => NotificationPreferences({...enabled, category: value});

  Map<String, dynamic> toColumns() => {
    for (final entry in enabled.entries) entry.key.wireName: entry.value,
  };
}
