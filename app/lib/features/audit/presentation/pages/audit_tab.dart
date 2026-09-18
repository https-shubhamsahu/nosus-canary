import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../theme.dart';
import '../../../../components/shimmer_box.dart';
import '../../../../components/async_state_view.dart';
import '../../providers/audit_provider.dart';
import '../../../../core/mascot/mascot_controller.dart';
import '../../../../core/mascot/mascot_state.dart';
import '../../../../core/mascot/mascot_view.dart';
import '../widgets/security_alerts_banner.dart';

class AuditTab extends ConsumerStatefulWidget {
  const AuditTab({super.key});

  @override
  ConsumerState<AuditTab> createState() => _AuditTabState();
}

class _AuditTabState extends ConsumerState<AuditTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Nox keeps watch over the ledger — an ongoing presence, not a claim
      // that a cryptographic check ran (this screen doesn't call
      // verify_audit_chain yet; don't imply verification that isn't there).
      if (mounted) ref.read(noxMascotProvider.notifier).play(MascotMood.observe);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auditLogsAsync = ref.watch(auditLogsProvider);

    return RefreshIndicator(
      key: const ValueKey('audit_tab'),
      onRefresh: () async {
        ref.invalidate(auditLogsProvider);
        await ref.read(auditLogsProvider.future);
      },
      color: theme.colorScheme.onSurface,
      backgroundColor: isDark ? NoSusTheme.dCard : NoSusTheme.lCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'SECURITY LEDGER & AUDIT LOGS',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
              const MascotView(character: MascotCharacter.nox, size: 22),
            ],
          ),
          const SizedBox(height: NoSusTheme.s24),

          const SecurityAlertsBanner(),

          // List of audit records
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: NoSusTheme.cardDecoration(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(NoSusTheme.r16),
                child: AsyncStateView<List<Map<String, String>>>(
                  value: auditLogsAsync,
                  onRetry: () => ref.invalidate(auditLogsProvider),
                  errorMessage: 'Failed to load the audit ledger',
                  loading: (context) => Padding(
                    padding: const EdgeInsets.all(NoSusTheme.s24),
                    child: ShimmerListSkeleton(
                      spacing: NoSusTheme.s24,
                      itemBuilder: (context) => const _AuditLogRowSkeleton(),
                    ),
                  ),
                  isEmpty: (logs) => logs.isEmpty,
                  empty: (context) => _buildEmptyState(theme),
                  data: (context, auditLogs) => ListView.separated(
                    padding: const EdgeInsets.all(NoSusTheme.s24),
                    itemCount: auditLogs.length,
                    physics: AlwaysScrollableScrollPhysics(
                      parent: NoSusTheme.getScrollPhysics(context),
                    ),
                    separatorBuilder: (context, index) => Divider(
                      color: theme.colorScheme.outline.withValues(alpha: 0.15),
                      height: NoSusTheme.s24,
                    ),
                    itemBuilder: (context, index) {
                      final log = auditLogs[index];

                      Color statusColor;
                      switch (log['status']) {
                        case 'SUCCESS':
                          statusColor = const Color(0xFF10B981);
                          break;
                        case 'SECURITY':
                          statusColor = Colors.amber;
                          break;
                        default:
                          statusColor = theme.colorScheme.onSurface
                              .withValues(alpha: 0.4);
                      }

                      return Row(
                        children: [
                          // Status dot
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: NoSusTheme.s16),
                          // Time
                          Text(
                            log['time'] ?? '',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontFamily: 'Courier',
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: NoSusTheme.s24),
                          // Event description
                          Expanded(
                            child: Text(
                              log['event'] ?? '',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.85,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 300.ms),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    final subtle = theme.colorScheme.onSurface.withValues(alpha: 0.4);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(
          parent: NoSusTheme.getScrollPhysics(context),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(NoSusTheme.s24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_toggle_off_outlined, size: 48, color: subtle),
                  const SizedBox(height: 16),
                  Text(
                    'NO ACTIVITY YET',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Security and access events will appear here.',
                    style: TextStyle(color: subtle, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shimmer placeholder matching one audit-log row: status dot + time + event.
class _AuditLogRowSkeleton extends StatelessWidget {
  const _AuditLogRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        ShimmerBox(width: 8, height: 8, radius: 4),
        SizedBox(width: NoSusTheme.s16),
        ShimmerBox(width: 60, height: 13),
        SizedBox(width: NoSusTheme.s24),
        Expanded(child: ShimmerBox(width: double.infinity, height: 14)),
      ],
    );
  }
}
