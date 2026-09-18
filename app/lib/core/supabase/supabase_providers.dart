import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  if (!SupabaseService.instance.isReachable) {
    throw StateError('Supabase is offline');
  }
  return Supabase.instance.client;
});
