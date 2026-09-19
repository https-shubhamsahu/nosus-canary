import 'package:flutter/material.dart';

import 'canary_home_screen.dart';

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
    final fg = theme.colorScheme.onSurface;

    return Semantics(
      button: true,
      label:
          'NO SUS Canary. Every reader gets their own copy. If it leaks, see whose copy it was.',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Material(
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: fg, width: 1.4),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _open(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.flutter_dash, color: fg, size: 28),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: fg),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'NEW',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontSize: 11,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('NO SUS Canary', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    'Every reader gets their own copy. If it leaks, see whose copy it was.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _open(context),
                      child: const Text('Open NO SUS Canary'),
                    ),
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
