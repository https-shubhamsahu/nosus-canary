import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:no_sus/features/groups/providers/groups_provider.dart';

void main() {
  test('searchQueryProvider initializes with empty string and updates correctly', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Initial state
    expect(container.read(searchQueryProvider), '');

    // Update state
    container.read(searchQueryProvider.notifier).update('crypto');
    expect(container.read(searchQueryProvider), 'crypto');
  });
}
