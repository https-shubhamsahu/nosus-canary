import 'package:flutter/material.dart';

/// One explainable concept in the product.
///
/// Content lives in Dart rather than a remote table on purpose: Help has to
/// work for a signed-out visitor who has never reached Supabase, and it is the
/// surface a confused user reaches for when the network is the thing that is
/// broken.
class HelpTopic {
  /// Stable identifier. Contextual "What's this?" buttons deep-link by id, so
  /// renaming a topic must not change it.
  final String id;
  final String title;

  /// One line shown in the topic list — the answer in miniature, not a teaser.
  final String summary;
  final IconData icon;
  final List<HelpSection> sections;

  /// Extra words that should match this topic in search but do not belong in
  /// the visible copy (jargon, old names, symptoms).
  final List<String> keywords;

  const HelpTopic({
    required this.id,
    required this.title,
    required this.summary,
    required this.icon,
    required this.sections,
    this.keywords = const [],
  });

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (title.toLowerCase().contains(q)) return true;
    if (summary.toLowerCase().contains(q)) return true;
    if (keywords.any((k) => k.toLowerCase().contains(q))) return true;
    return sections.any(
      (s) =>
          s.heading.toLowerCase().contains(q) ||
          s.body.toLowerCase().contains(q),
    );
  }
}

class HelpSection {
  final String heading;
  final String body;

  /// Renders as a caution callout. Used for the places where the product's
  /// protection genuinely stops — never softened into marketing.
  final bool isCaution;

  const HelpSection({
    required this.heading,
    required this.body,
    this.isCaution = false,
  });
}

/// The help catalogue.
///
/// Every claim here must describe something that actually ships. In particular
/// the screenshot-blocking copy is scoped to Android because `ScreenshotGuard`
/// returns early on web and iOS — overstating that would break the honesty rule
/// in PROJECT_CONSTITUTION.md §2.3, which outranks polish.
abstract final class HelpCatalog {
  static const String whatIsNoSus = 'what-is-no-sus';
  static const String groups = 'groups';
  static const String roles = 'roles';
  static const String secureDocuments = 'secure-documents';
  static const String watermarking = 'watermarking';
  static const String burnNotes = 'burn-notes';
  static const String burnFiles = 'burn-files';
  static const String shareLinks = 'share-links';
  static const String auditLog = 'audit-log';
  static const String notifications = 'notifications';
  static const String account = 'account';
  static const String troubleshooting = 'troubleshooting';

  static const List<HelpTopic> topics = [
    HelpTopic(
      id: whatIsNoSus,
      title: 'What NO SUS is',
      summary:
          'A workspace for sharing study material with people you choose — and knowing what happened to it afterwards.',
      icon: Icons.help_outline,
      keywords: ['about', 'overview', 'start', 'what is this', 'purpose'],
      sections: [
        HelpSection(
          heading: 'The short version',
          body:
              'You put documents somewhere only your group can reach them, you open them in a viewer that '
              'discourages casual copying, and every open is written to a log the whole group can see. '
              'The point is not that leaking becomes impossible — it is that it stops being anonymous.',
        ),
        HelpSection(
          heading: 'Two halves of the app',
          body:
              'Groups and documents need an account, because they are tied to who you are.\n\n'
              'Burn Notes, Burn Files and code redemption do not. Nobody signs in on either end of those — '
              'not the sender, not the recipient.',
        ),
        HelpSection(
          heading: 'Where things live',
          body:
              'Workspace is your home: quick tools and your private scratchpad.\n'
              'Vault is every document shared with you across all your groups.\n'
              'Study Desk is the secure reader you open documents in.\n'
              'Activity is the audit log.\n'
              'Groups is where communities and their files live.',
        ),
      ],
    ),
    HelpTopic(
      id: groups,
      title: 'Groups and communities',
      summary:
          'A group is a private space with its own members, files and activity log. You join by invite.',
      icon: Icons.group_outlined,
      keywords: ['community', 'join', 'invite', 'create group', 'leave'],
      sections: [
        HelpSection(
          heading: 'Joining',
          body:
              'You need an invite link or an invite code. Opening an invite link shows you the group name '
              'and how many members it has before you commit to anything.\n\n'
              'There is no directory to browse. If you were not invited, you cannot find or join a group.',
        ),
        HelpSection(
          heading: 'Creating',
          body:
              'Groups → the + button. You become the group admin. Turning on an invite code generates a '
              'shareable 8-character code; leave it off to add people only through invite links you '
              'generate yourself.',
        ),
        HelpSection(
          heading: 'Leaving',
          body:
              'Open the group → the menu in the top right → Leave group. You lose access to its files '
              'immediately. Anything you uploaded stays with the group.',
        ),
        HelpSection(
          heading: 'Global Community',
          body:
              'Every new account joins one shared group called Global Community so the app is not empty on '
              'day one. Treat it as public: assume anyone with a NO SUS account can read what you put there. '
              'You can leave it like any other group.',
          isCaution: true,
        ),
      ],
    ),
    HelpTopic(
      id: roles,
      title: 'Roles and permissions',
      summary:
          'Groups have admins and members. Admins manage people and content; members read and contribute.',
      icon: Icons.shield_outlined,
      keywords: [
        'admin',
        'member',
        'permission',
        'promote',
        'demote',
        'remove',
        'ban',
        'moderation',
      ],
      sections: [
        HelpSection(
          heading: 'Members can',
          body:
              'Read every file in the group, upload their own, rename and delete what they uploaded, and '
              'see the full activity log.',
        ),
        HelpSection(
          heading: 'Admins can also',
          body:
              'Promote and demote other members, remove members, ban and unban people, delete anyone\'s '
              'file, manage invite links, and delete the group.',
        ),
        HelpSection(
          heading: 'How it is enforced',
          body:
              'By the database, not by the app. Hiding a button is a convenience; the permission check runs '
              'server-side on every write. An edited client gets a rejection, not a shortcut.',
        ),
        HelpSection(
          heading: 'Banning',
          body:
              'A ban removes someone and blocks them from rejoining with any invite. Unbanning lets them '
              'accept an invite again — it does not re-add them automatically.',
        ),
      ],
    ),
    HelpTopic(
      id: secureDocuments,
      title: 'Secure documents',
      summary:
          'Files shared into a group open in a reader built to make copying awkward and attributable.',
      icon: Icons.description_outlined,
      keywords: [
        'file',
        'upload',
        'pdf',
        'vault',
        'study desk',
        'spyglass',
        'viewer',
      ],
      sections: [
        HelpSection(
          heading: 'Uploading',
          body:
              'Open a group → Files → the upload button. Everyone in that group can read it. There is no '
              'per-file audience inside a group — the group is the audience.',
        ),
        HelpSection(
          heading: 'Reading',
          body:
              'Tap Reveal on any file to open it in the Study Desk. Documents are streamed into memory for '
              'the session rather than saved to your device\'s file system.',
        ),
        HelpSection(
          heading: 'Touch to reveal',
          body:
              'Content sits behind a blur until you hold your finger on it. It is aimed at the person '
              'standing behind you, not at a determined attacker. Turn it off in Settings → Privacy & '
              'Security.',
        ),
        HelpSection(
          heading: 'What this does not do',
          body:
              'It does not encrypt files end-to-end — group documents are stored server-side and access is '
              'enforced by database rules. If that is your threat model, use Burn Files instead: those are '
              'encrypted on your device and the key never reaches the server.',
          isCaution: true,
        ),
      ],
    ),
    HelpTopic(
      id: watermarking,
      title: 'Watermarks and screenshots',
      summary:
          'Open documents carry your identity on-screen, and on Android the system screenshot is blocked.',
      icon: Icons.branding_watermark_outlined,
      keywords: ['watermark', 'screenshot', 'screen record', 'capture', 'leak'],
      sections: [
        HelpSection(
          heading: 'Watermarking',
          body:
              'Your email and a timestamp are drawn over every page you open. A photograph of the screen '
              'carries them too, which is the point: a leaked page identifies the session it came from.',
        ),
        HelpSection(
          heading: 'Screenshot blocking is Android-only',
          body:
              'On Android the app sets the system flag that blocks screenshots and screen recording, and '
              'logs the attempt. On the web app and on iOS there is no such flag — nothing stops a '
              'screenshot there, and the app does not pretend otherwise. The watermark and the audit log '
              'are what protect you on those platforms.',
          isCaution: true,
        ),
        HelpSection(
          heading: 'A camera always wins',
          body:
              'No app can stop someone photographing their own screen with another device. Every control '
              'here is designed for attribution after the fact, not prevention.',
          isCaution: true,
        ),
      ],
    ),
    HelpTopic(
      id: burnNotes,
      title: 'Burn Notes',
      summary:
          'Send a secret that is destroyed the moment it is read. No account needed, on either end.',
      icon: Icons.local_fire_department_outlined,
      keywords: [
        'secret',
        'self destruct',
        'one time',
        'password',
        'anonymous',
      ],
      sections: [
        HelpSection(
          heading: 'How it works',
          body:
              'Your note is encrypted on your device. Only the encrypted blob is uploaded — the key is put '
              'in the link, after the # symbol, which browsers never send to a server. The first person to '
              'open the link gets the note and the stored copy is deleted.',
        ),
        HelpSection(
          heading: 'Sending the link safely',
          body:
              'The link is the secret. Anyone who sees it can read the note, once. Send it over a different '
              'channel than the thing it protects.',
        ),
        HelpSection(
          heading: 'It really is one read',
          body:
              'If a link preview service or an over-eager chat client fetches the link, it burns. The '
              'recipient then sees "already read" — which is your signal that something opened it first.',
          isCaution: true,
        ),
      ],
    ),
    HelpTopic(
      id: burnFiles,
      title: 'Burn Files',
      summary:
          'The same idea as a Burn Note, for files. Encrypted on your device, deleted after one download.',
      icon: Icons.upload_file_outlined,
      keywords: [
        'file',
        'anonymous',
        'upload',
        'self destruct',
        'send file',
        'size limit',
      ],
      sections: [
        HelpSection(
          heading: 'How it works',
          body:
              'Each file is encrypted on your device with its own key before anything is uploaded. The keys '
              'ride in the link fragment and never reach the server. First download wins; the stored copy '
              'is then deleted.',
        ),
        HelpSection(
          heading: 'Limits',
          body:
              'Up to 10 files and 25 MB combined per share. Larger uploads are rejected before anything '
              'leaves your device, so a too-big file fails instantly rather than after a long upload.',
        ),
        HelpSection(
          heading: 'Short codes',
          body:
              'A single-file share can also generate a short code for someone to type in, for when a long '
              'link is awkward. Multi-file shares are link-only.',
        ),
      ],
    ),
    HelpTopic(
      id: shareLinks,
      title: 'Share links and codes',
      summary:
          'Send one group document to someone outside the group, and see when they opened it.',
      icon: Icons.link_outlined,
      keywords: [
        'securesend',
        'external',
        'link',
        'redeem',
        'code',
        'analytics',
        'revoke',
      ],
      sections: [
        HelpSection(
          heading: 'Sharing outward',
          body:
              'A share link lets one person read one document without joining the group. They open it in a '
              'watermarked viewer — they never get the file itself.',
        ),
        HelpSection(
          heading: 'Seeing what happened',
          body:
              'You get a view log for each link: when it was opened and from where. If a link is opened by '
              'someone you did not send it to, that shows up.',
        ),
        HelpSection(
          heading: 'Redeeming a code',
          body:
              'Workspace → Redeem a Code. Codes are single-use and expire; once redeemed the content is '
              'gone for everyone, including you.',
        ),
      ],
    ),
    HelpTopic(
      id: auditLog,
      title: 'Activity and the audit log',
      summary:
          'Every meaningful action in a group is recorded, in order, visible to the whole group.',
      icon: Icons.history_edu_outlined,
      keywords: ['audit', 'log', 'activity', 'history', 'who opened', 'tamper'],
      sections: [
        HelpSection(
          heading: 'What is recorded',
          body:
              'Joins and leaves, uploads, renames, deletions, document opens, screenshot attempts, and '
              'moderation actions. Entries record who and when — never the contents of a document.',
        ),
        HelpSection(
          heading: 'Why it is visible to everyone',
          body:
              'Accountability only works if it is mutual. Members can see admins\' actions as readily as '
              'admins see members\'. Nobody gets a private log.',
        ),
        HelpSection(
          heading: 'Tamper evidence',
          body:
              'Entries are chained together, so removing or editing one breaks the chain and is detectable. '
              'The log is append-only — actions cannot be quietly retracted, including by admins.',
        ),
      ],
    ),
    HelpTopic(
      id: notifications,
      title: 'Notifications',
      summary:
          'Get told when something you care about happens, without the details showing on your lock screen.',
      icon: Icons.notifications_none_outlined,
      keywords: [
        'push',
        'alert',
        'permission',
        'mute',
        'lock screen',
        'privacy',
      ],
      sections: [
        HelpSection(
          heading: 'What you can be notified about',
          body:
              'Invitations and join requests, role changes, moderation actions affecting you, documents '
              'shared into your groups, and security events on your account. Each category can be turned '
              'off on its own in Settings → Notifications.',
        ),
        HelpSection(
          heading: 'Nothing sensitive on the lock screen',
          body:
              'Notification text names the group and the kind of event — never a document\'s name or '
              'contents. Anyone glancing at your phone learns that something happened, not what.',
        ),
        HelpSection(
          heading: 'If you said no to the permission',
          body:
              'Android only asks once. Everything still appears in the in-app inbox, and Settings → '
              'Notifications has a shortcut to the system settings page if you change your mind.',
        ),
      ],
    ),
    HelpTopic(
      id: account,
      title: 'Your account and your data',
      summary:
          'What is stored about you, who can see it, and how to change or delete it.',
      icon: Icons.person_outline,
      keywords: [
        'profile',
        'password',
        'delete account',
        'privacy',
        'email',
        'data',
      ],
      sections: [
        HelpSection(
          heading: 'What is stored',
          body:
              'Your email, display name and avatar choice. Documents you upload to groups. Audit entries '
              'for actions you took. That is the account; there is no advertising profile behind it.',
        ),
        HelpSection(
          heading: 'Who can see your email',
          body:
              'Other members of groups you are in — the audit log names people by email, which is what '
              'makes it useful. If that matters to you, be deliberate about which groups you join.',
          isCaution: true,
        ),
        HelpSection(
          heading: 'Deleting your account',
          body:
              'Settings → Danger Zone → Delete account. It removes your profile and every group membership '
              'permanently and cannot be undone. Audit entries recording actions you took stay, because the '
              'log is append-only and other members rely on it.',
        ),
      ],
    ),
    HelpTopic(
      id: troubleshooting,
      title: 'When something goes wrong',
      summary: 'The failures people actually hit, and what each one means.',
      icon: Icons.build_outlined,
      keywords: [
        'error',
        'expired',
        'broken',
        'cannot open',
        'offline',
        'stuck',
        'failed',
      ],
      sections: [
        HelpSection(
          heading: '"This link has already been opened"',
          body:
              'A Burn Note or Burn File is genuinely gone — that is the feature working. Ask the sender for '
              'a new one. If you never opened it, assume something else did and treat the contents as '
              'exposed.',
        ),
        HelpSection(
          heading: '"This invite has expired or been revoked"',
          body:
              'Invite links can have an expiry date and a usage limit, and an admin can revoke one. Ask for '
              'a fresh link.',
        ),
        HelpSection(
          heading: 'A document will not open',
          body:
              'Usually access was removed — you left the group, were removed from it, or the file was '
              'deleted. Pull to refresh; if the file is gone from the list, it was deleted.',
        ),
        HelpSection(
          heading: 'The app says it is offline',
          body:
              'Groups, documents and the audit log need a connection. Burn Notes and Burn Files need one '
              'too, to upload. Your private scratchpad keeps working, and syncs when you are back.',
        ),
        HelpSection(
          heading: 'Signed out unexpectedly',
          body:
              'If unusual security signals are detected on your account, the app asks you to sign in again. '
              'That is a refresh, not a lockout — signing back in clears the flag if the risk has passed.',
        ),
      ],
    ),
  ];

  static HelpTopic? byId(String id) {
    for (final t in topics) {
      if (t.id == id) return t;
    }
    return null;
  }

  static List<HelpTopic> search(String query) =>
      topics.where((t) => t.matches(query)).toList(growable: false);
}
