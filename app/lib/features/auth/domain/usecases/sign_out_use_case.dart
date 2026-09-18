import '../repositories/auth_repository.dart';

class SignOutUseCase {
  final AuthRepository _repository;

  const SignOutUseCase(this._repository);

  Future<void> call() async {
    return await _repository.signOut();
  }
}
