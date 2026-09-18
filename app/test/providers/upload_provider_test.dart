import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:no_sus/features/auth/domain/entities/authenticated_user.dart';
import 'package:no_sus/features/auth/presentation/providers/auth_providers.dart';
import 'package:no_sus/features/files/domain/models/secure_file_metadata.dart';
import 'package:no_sus/features/files/domain/repositories/secure_file_repository.dart';
import 'package:no_sus/features/files/presentation/providers/secure_file_providers.dart';
import 'package:no_sus/features/files/presentation/providers/upload_provider.dart';
import 'package:no_sus/features/groups/models/group_file.dart';
import 'package:no_sus/features/auth/domain/repositories/auth_repository.dart';

class MockSecureFileRepository extends Mock implements SecureFileRepository {}
class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(SecureFileType.pdf);
    registerFallbackValue(Uint8List(0));
  });

  group('UploadNotifier', () {
    late MockSecureFileRepository mockRepo;
    late MockAuthRepository mockAuthRepo;
    late ProviderContainer container;

    setUp(() {
      mockRepo = MockSecureFileRepository();
      mockAuthRepo = MockAuthRepository();

      when(() => mockAuthRepo.currentUser).thenReturn(
        const AuthenticatedUser(id: 'u1', email: 'test@nosus.io'),
      );

      container = ProviderContainer(
        overrides: [
          secureFileRepositoryProvider.overrideWithValue(mockRepo),
          authRepositoryProvider.overrideWithValue(mockAuthRepo),
          // Ignore profile provider for simple test
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is idle', () {
      final state = container.read(uploadProvider);
      expect(state.stage, UploadStage.idle);
      expect(state.progress, 0.0);
    });

    test('uploadDocument successful flow', () async {
      when(() => mockRepo.uploadFile(
        groupId: any(named: 'groupId'),
        name: any(named: 'name'),
        type: any(named: 'type'),
        rawBytes: any(named: 'rawBytes'),
        uploaderName: any(named: 'uploaderName'),
        uploaderInitials: any(named: 'uploaderInitials'),
        onProgress: any(named: 'onProgress'),
      )).thenAnswer((invocation) async {
        final onProgress = invocation.namedArguments[#onProgress] as void Function(double)?;
        if (onProgress != null) {
          onProgress(0.5);
          onProgress(1.0);
        }
      });

      final notifier = container.read(uploadProvider.notifier);
      
      final future = notifier.uploadDocument(
        'test.pdf',
        FileType.pdf,
        'g1',
        Uint8List.fromList([1, 2, 3]),
      );
      
      expect(container.read(uploadProvider).stage, UploadStage.processing);
      
      await future;

      verify(() => mockRepo.uploadFile(
        groupId: 'g1',
        name: 'test.pdf',
        type: SecureFileType.pdf,
        rawBytes: any(named: 'rawBytes'),
        uploaderName: any(named: 'uploaderName'),
        uploaderInitials: any(named: 'uploaderInitials'),
        onProgress: any(named: 'onProgress'),
      )).called(1);
    });

    test('uploadDocument error flow', () async {
      when(() => mockRepo.uploadFile(
        groupId: any(named: 'groupId'),
        name: any(named: 'name'),
        type: any(named: 'type'),
        rawBytes: any(named: 'rawBytes'),
        uploaderName: any(named: 'uploaderName'),
        uploaderInitials: any(named: 'uploaderInitials'),
        onProgress: any(named: 'onProgress'),
      )).thenThrow(Exception('Upload failed'));

      final notifier = container.read(uploadProvider.notifier);
      await notifier.uploadDocument(
        'test.pdf',
        FileType.pdf,
        'g1',
        Uint8List.fromList([1, 2, 3]),
      );

      final state = container.read(uploadProvider);
      expect(state.stage, UploadStage.error);
      expect(state.errorMessage, contains('Upload failed'));
    });
  });
}
