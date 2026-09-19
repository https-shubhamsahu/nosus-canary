import 'package:flutter/material.dart';

import '../../../theme.dart';
import 'canary_home_screen.dart';
import 'ui/canary_mark.dart';

/// Entry point shown on Welcome (no account needed) and in Workspace.
class CanaryEntryCard extends StatelessWidget {
  const CanaryEntryCard({super.key, this.onOpen});

  /// When set, used instead of pushing [CanaryHomeScreen] (Welcome analytics).
  final VoidCallback? onOpen;

  void _open(BuildContext context) {
    if (onOpen != null) {
      onOpen!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CanaryHomeScreen(),
        settings: const RouteSettings(name: '/canary'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label:
          'NO SUS Canary. Every reader gets their own copy. If it leaks, see whose copy it was.',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: CanaryTokens.brand,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(1.4),
          child: Material(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14.6),
            child: InkWell(
              borderRadius: BorderRadius.circular(14.6),
              onTap: () => _open(context),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CanaryMark(size: 28),
                        const SizedBox(width: 10),
                        Text(
                          'NO SUS Canary',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: CanaryTokens.canary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              color: CanaryTokens.onCanary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Every reader gets their own copy. If it leaks, see whose copy it was.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Open Canary →',
                          style: TextStyle(
                            color: CanaryTokens.canary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
