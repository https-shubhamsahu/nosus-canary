// ignore_for_file: avoid_print
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:no_sus/services/supabase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'Supabase Storage Integration Tests',
    () {
      setUpAll(() async {
        await SupabaseService.instance.initialize();
      });

      test('Upload, Download, and Delete flow via Supabase Storage', () async {
        expect(
          SupabaseService.instance.isConfigured,
          isTrue,
          reason: 'Supabase credentials should be configured',
        );

        final client = Supabase.instance.client;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final email = 'integration_test_$timestamp@example.com';
        final password = 'Password123!';

        print('Signing up integration test user: $email...');
        final authRes = await client.auth.signUp(email: email, password: password);
        final user = authRes.user;
        expect(user, isNotNull);
        final userId = user!.id;

        // The signup trigger handle_new_user auto-joins the user to the Global Community
        // and creates the group if it doesn't exist. Let's define the group ID.
        const globalGroupId = '8055b43a-6d07-4588-a39f-159e6154a019';

        final testFileName = 'file_test_integration_$timestamp';
        final testData = Uint8List.fromList([
          104,
          101,
          108,
          108,
          111,
          32,
          119,
          111,
          114,
          108,
          100,
        ]);

        // Insert metadata record first to satisfy RLS SELECT/INSERT constraints if needed.
        // Wait, for INSERT into storage.objects, we check bucket_id = 'secure-files' and auth.uid() = owner_id.
        // For SELECT, we check group membership via public.secure_files.
        print('Inserting secure file metadata to public.secure_files...');
        await client.from('secure_files').insert({
          'id': testFileName,
          'group_id': globalGroupId,
          'name': 'Test Integration File',
          'type': 'pdf',
          'size_bytes': testData.length,
          'is_watermarked': true,
          'is_pinned': false,
          'security_status': 'secured',
          'owner_id': userId,
          'uploaded_by': userId,
        });

        print('Uploading test bytes to Supabase Storage...');
        await client.storage
            .from('secure-files')
            .uploadBinary(testFileName, testData);

        print('Downloading test bytes...');
        final downloadedData = await client.storage
            .from('secure-files')
            .download(testFileName);
        expect(downloadedData, equals(testData));

        print('Deleting test file from storage...');
        await client.storage
            .from('secure-files')
            .remove([testFileName]);

        print('Deleting test file metadata...');
        await client.from('secure_files').delete().eq('id', testFileName);

        print('Cleaning up: deleting test auth user...');
        // We cannot delete ourselves via Client API. We can run it in database after or just delete the user's session.
        await client.auth.signOut();
      });
    },
    skip: 'Requires live Supabase project credentials.',
  );
}
