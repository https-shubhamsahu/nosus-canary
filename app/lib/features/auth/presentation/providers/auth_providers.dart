import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_bootstrap.dart';
import '../../../../core/supabase/supabase_providers.dart';
import '../../../../services/supabase_service.dart';

import '../../data/repositories/supabase_auth_repository.dart';
import '../../data/repositories/mock_auth_repository.dart';
import '../../data/services/supabase_auth_service.dart';
import '../../domain/entities/authenticated_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/sign_in_use_case.dart';
import '../../domain/usecases/sign_up_use_case.dart';
import '../../domain/usecases/sign_out_use_case.dart';

final supabaseAuthServiceProvider = Provider<SupabaseAuthService>((ref) {
  return SupabaseAuthService(ref.watch(supabaseClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (SupabaseBootstrap.isConfigured && SupabaseService.instance.isReachable) {
    return SupabaseAuthRepository(ref.watch(supabaseAuthServiceProvider));
  } else {
    return const MockAuthRepository();
  }
});

final authStateProvider = StreamProvider<AuthenticatedUser?>((ref) {
  return ref.watch(authRepositoryProvider).watchAuthState();
});

/// Profile data is loaded once for the active session rather than each time
/// [AuthGate] rebuilds for a theme, risk, or auth event. An empty result means
/// onboarding is needed; it must never be treated as a reason to sign out.
final sessionProfileProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return {};
  return SupabaseService.instance.fetchProfile(user.id);
});

final signInUseCaseProvider = Provider<SignInUseCase>((ref) {
  return SignInUseCase(ref.watch(authRepositoryProvider));
});

final signUpUseCaseProvider = Provider<SignUpUseCase>((ref) {
  return SignUpUseCase(ref.watch(authRepositoryProvider));
});

final signOutUseCaseProvider = Provider<SignOutUseCase>((ref) {
  return SignOutUseCase(ref.watch(authRepositoryProvider));
});

/// True once the user has opened a password-recovery link and is holding a
/// temporary recovery session. [AuthGate] checks this before its normal
/// signed-in check so recovery lands on "set a new password" instead of
/// straight into the app with an unchanged password.
class PasswordRecoveryNotifier extends Notifier<bool> {
  @override
  bool build() {
    if (!SupabaseBootstrap.isConfigured ||
        !SupabaseService.instance.isReachable) {
      return false;
    }
    final sub = ref.watch(supabaseClientProvider).auth.onAuthStateChange.listen(
      (state) {
        if (state.event == AuthChangeEvent.passwordRecovery) {
          this.state = true;
        }
      },
    );
    ref.onDispose(sub.cancel);
    return false;
  }

  void clear() => state = false;
}

final passwordRecoveryProvider =
    NotifierProvider<PasswordRecoveryNotifier, bool>(
      PasswordRecoveryNotifier.new,
    );
