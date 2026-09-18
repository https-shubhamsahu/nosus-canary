import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';

import '../../data/repositories/supabase_secure_file_repository.dart';
import '../../domain/models/secure_file_metadata.dart';
import '../../domain/repositories/secure_file_repository.dart';

final secureFileRepositoryProvider = Provider<SecureFileRepository>((ref) {
  return SupabaseSecureFileRepository(ref.watch(supabaseClientProvider));
});

final secureFileMetadataProvider =
    StreamProvider.family<List<SecureFileMetadata>, String>((ref, groupId) {
      return ref.watch(secureFileRepositoryProvider).watchGroupFiles(groupId);
    });
