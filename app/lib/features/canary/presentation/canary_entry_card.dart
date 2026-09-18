import 'package:flutter/material.dart';

import 'canary_home_screen.dart';

/// Entry point shown on Welcome (no account needed) and in Workspace.
class CanaryEntryCard extends StatelessWidget {
  const CanaryEntryCard({super.key});

  @override
  Widget build(BuildContext context) => Card.outlined(
    margin: const EdgeInsets.symmetric(vertical: 12),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      leading: const Icon(Icons.flutter_dash),
      title: const Text('NO SUS Canary'),
      subtitle: const Text(
        'Every reader gets their own copy. If it leaks, see whose copy it was.',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const CanaryHomeScreen(),
          settings: const RouteSettings(name: '/canary'),
        ),
      ),
    ),
  );
}
