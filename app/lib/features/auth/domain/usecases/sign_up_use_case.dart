import '../repositories/auth_repository.dart';
import '../entities/authenticated_user.dart';

class SignUpUseCase {
  final AuthRepository _repository;

  const SignUpUseCase(this._repository);

  Future<AuthenticatedUser> call({
    required String email,
    required String password,
  }) async {
    return await _repository.signUp(email: email, password: password);
  }
}
