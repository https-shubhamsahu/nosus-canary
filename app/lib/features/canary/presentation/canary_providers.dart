import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/theme_provider.dart'
    show sharedPreferencesProvider;
import '../data/canary_repository.dart';
import '../data/canary_store.dart';

/// sharedPreferencesProvider is overridden with a warm instance in main.dart
/// (both the normal app and every standalone runApp branch).
final canaryRepositoryProvider = Provider<CanaryRepository>((ref) {
  return CanaryRepository(CanaryStore(ref.watch(sharedPreferencesProvider)));
});
