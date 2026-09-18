import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../data/repositories/supabase_study_group_repository.dart';
import '../../domain/repositories/study_group_repository.dart';

final studyGroupRepositoryProvider = Provider<StudyGroupRepository>((ref) {
  return SupabaseStudyGroupRepository(ref.watch(supabaseClientProvider));
});
