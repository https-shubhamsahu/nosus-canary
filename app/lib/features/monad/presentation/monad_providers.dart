import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/monad_rpc_repository.dart';
import '../domain/monad_repository.dart';

final monadRepositoryProvider = Provider<MonadRepository>((ref) {
  final repository = MonadRpcRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

// Not an environment flag. Requires browser custody implementation and all
// six recorded Gate T1 proofs before it may become true.
const monadThresholdVerified = false;
