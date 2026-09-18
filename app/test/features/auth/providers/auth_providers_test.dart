import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:no_sus/features/auth/domain/repositories/auth_repository.dart';
import 'package:no_sus/features/auth/domain/usecases/sign_in_use_case.dart';
import 'package:no_sus/features/auth/domain/usecases/sign_up_use_case.dart';
import 'package:no_sus/features/auth/domain/entities/authenticated_user.dart';
import 'package:no_sus/features/auth/domain/usecases/sign_out_use_case.dart';
import 'package:no_sus/features/auth/presentation/providers/auth_providers.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockAuthRepository;
  late ProviderContainer container;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('signInUseCaseProvider provides SignInUseCase with mocked repository', () async {
    final useCase = container.read(signInUseCaseProvider);
    expect(useCase, isA<SignInUseCase>());
    
    when(() => mockAuthRepository.signIn(email: 'test@test.com', password: 'password'))
        .thenAnswer((_) async => const AuthenticatedUser(id: 'test_id', email: 'test@test.com'));

    await useCase(email: 'test@test.com', password: 'password');
    verify(() => mockAuthRepository.signIn(email: 'test@test.com', password: 'password')).called(1);
  });

  test('signUpUseCaseProvider provides SignUpUseCase with mocked repository', () async {
    final useCase = container.read(signUpUseCaseProvider);
    expect(useCase, isA<SignUpUseCase>());
    
    when(() => mockAuthRepository.signUp(email: 'test@test.com', password: 'password'))
        .thenAnswer((_) async => const AuthenticatedUser(id: 'test_id', email: 'test@test.com'));

    await useCase(email: 'test@test.com', password: 'password');
    verify(() => mockAuthRepository.signUp(email: 'test@test.com', password: 'password')).called(1);
  });

  test('signOutUseCaseProvider provides SignOutUseCase with mocked repository', () async {
    final useCase = container.read(signOutUseCaseProvider);
    expect(useCase, isA<SignOutUseCase>());
    
    when(() => mockAuthRepository.signOut()).thenAnswer((_) async {});

    await useCase();
    verify(() => mockAuthRepository.signOut()).called(1);
  });
}
