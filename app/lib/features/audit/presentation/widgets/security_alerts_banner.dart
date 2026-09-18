import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../theme.dart';
import '../../../../services/supabase_service.dart';
import '../../providers/security_alerts_provider.dart';

/// Shows escalated security_alerts (tier 'high'/'critical' — see
/// recompute_user_risk in 20260710030000_risk_engine.sql) to whoever RLS
/// says can see them: group admins for their groups, super-admins for
/// everything, everyone for their own account. Renders nothing when the
/// list is empty, which is the common case for the vast majority of users —
/// this is a "surface the exception" panel, not a permanent fixture.
class SecurityAlertsBanner extends ConsumerWidget {
  const SecurityAlertsBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(securityAlertsProvider);

    return alertsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (alerts) {
        if (alerts.isEmpty) return const SizedBox.shrink();

        final theme = Theme.of(context);
        return Container(
          margin: const EdgeInsets.only(bottom: NoSusTheme.s24),
          width: double.infinity,
          padding: const EdgeInsets.all(NoSusTheme.s16),
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(NoSusTheme.r16),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.redAccent),
                  const SizedBox(width: NoSusTheme.s8),
                  Text(
                    'SECURITY ALERTS (${alerts.length})',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.redAccent,
                      letterSpacing: 1.2,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NoSusTheme.s12),
              for (final alert in alerts) _SecurityAlertRow(alert: alert),
            ],
          ),
        );
      },
    );
  }
}

class _SecurityAlertRow extends ConsumerWidget {
  final Map<String, dynamic> alert;
  const _SecurityAlertRow({required this.alert});

  static String _relativeTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tier = alert['tier'] as String? ?? 'high';
    final score = alert['score']?.toString() ?? '?';
    final groupId = alert['group_id'] as String?;
    final relTime = _relativeTime(alert['created_at'] as String?);
    final id = alert['id'] as String;
    final isCritical = tier == 'critical';
    final tierColor = isCritical ? Colors.redAccent : Colors.orangeAccent;

    final scopeLabel = groupId == null
        ? 'cross-group'
        : 'group ${groupId.length > 8 ? groupId.substring(0, 8) : groupId}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NoSusTheme.s8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: tierColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              tier.toUpperCase(),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tierColor),
            ),
          ),
          const SizedBox(width: NoSusTheme.s12),
          Expanded(
            child: Text(
              'Score $score · $scopeLabel · $relTime',
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            tooltip: 'Acknowledge',
            onPressed: () async {
              await SupabaseService.instance.acknowledgeSecurityAlert(id);
              ref.invalidate(securityAlertsProvider);
            },
          ),
        ],
      ),
    );
  }
}
