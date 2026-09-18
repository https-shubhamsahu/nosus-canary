import 'package:flutter/material.dart';
import 'monad_screen.dart';

class MonadEntryCard extends StatelessWidget {
  const MonadEntryCard({super.key});
  @override
  Widget build(BuildContext context) => Card.outlined(
    margin: const EdgeInsets.symmetric(vertical: 12),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      leading: const Icon(Icons.verified_outlined),
      title: const Text('Monad receipts'),
      subtitle: const Text(
        'A wallet acknowledgement for an encrypted note. Explore the experiment.',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const MonadScreen(),
          settings: const RouteSettings(name: '/monad'),
        ),
      ),
    ),
  );
}
