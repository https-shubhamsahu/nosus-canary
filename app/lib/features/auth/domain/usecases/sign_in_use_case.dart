import '../repositories/auth_repository.dart';
import '../entities/authenticated_user.dart';

class SignInUseCase {
  final AuthRepository _repository;

  const SignInUseCase(this._repository);

  Future<AuthenticatedUser> call({
    required String email,
    required String password,
  }) async {
    return await _repository.signIn(email: email, password: password);
  }

  Future<void> signInWithGoogle() async {
    return await _repository.signInWithGoogle();
  }

  Future<void> signInWithGitHub() async {
    return await _repository.signInWithGitHub();
  }

  Future<void> signInWithPhone(String phone) async {
    return await _repository.signInWithPhone(phone);
  }

  Future<AuthenticatedUser> verifyPhoneOtp(String phone, String otp) async {
    return await _repository.verifyPhoneOtp(phone, otp);
  }
}
