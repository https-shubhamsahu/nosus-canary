import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/main.dart';

// These lock the two shared-into-the-wild URL contracts. Links people have
// already sent must keep parsing forever — a regression here is a silent
// production outage for every link in flight.
void main() {
  const keyHex =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'; // 64
  const ivHex = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'; // 32
  const noteId = '01234567-89ab-cdef-0123-456789abcdef';

  group('extractBurnNoteToken', () {
    test('parses the production nosus.foo link format', () {
      final uri = Uri.parse(
        'https://nosus.foo/#/burn/$noteId?k=$keyHex&v=$ivHex',
      );
      final token = extractBurnNoteToken(uri);
      expect(token, isNotNull);
      expect(token!.id, noteId);
      expect(token.keyHex, keyHex);
      expect(token.ivHex, ivHex);
    });

    test('parses the legacy GitHub Pages subdirectory link format', () {
      // Links shared before the nosus.foo migration must keep resolving —
      // GitHub Pages 301-redirects the old .github.io URL to the custom
      // domain, but the fragment/query parsing itself must still work
      // regardless of which host or base path served the page.
      final uri = Uri.parse(
        'https://https-shubhamsahu.github.io/NON_SUS/#/burn/$noteId?k=$keyHex&v=$ivHex',
      );
      final token = extractBurnNoteToken(uri);
      expect(token, isNotNull);
      expect(token!.id, noteId);
      expect(token.keyHex, keyHex);
      expect(token.ivHex, ivHex);
    });

    test('parses with a cache-buster query before the fragment', () {
      final uri = Uri.parse(
        'https://host/NON_SUS/?cb=1234#/burn/$noteId?k=$keyHex&v=$ivHex',
      );
      expect(extractBurnNoteToken(uri), isNotNull);
    });

    test('parses the legacy double-hash format', () {
      final uri = Uri.parse('https://host/#/burn/$noteId%23$keyHex.$ivHex');
      final token = extractBurnNoteToken(uri);
      expect(token, isNotNull);
      expect(token!.id, noteId);
    });

    test('rejects wrong-length keys', () {
      final uri = Uri.parse('https://host/#/burn/$noteId?k=deadbeef&v=$ivHex');
      expect(extractBurnNoteToken(uri), isNull);
    });

    test('returns null on ordinary app URLs', () {
      expect(extractBurnNoteToken(Uri.parse('https://host/NON_SUS/')), isNull);
      expect(extractBurnNoteToken(Uri.parse('file:///')), isNull);
    });
  });

  group('extractShareToken', () {
    test('parses token from hash fragment', () {
      expect(
        extractShareToken(Uri.parse('https://host/NON_SUS/?cb=1#/v/abc123')),
        'abc123',
      );
    });

    test('parses token from path', () {
      expect(extractShareToken(Uri.parse('https://host/v/tok9')), 'tok9');
    });

    test('returns null when absent', () {
      expect(extractShareToken(Uri.parse('https://host/NON_SUS/')), isNull);
    });
  });

  group('extractInviteToken', () {
    test('parses invite code from hash fragment (nosus.foo)', () {
      expect(
        extractInviteToken(Uri.parse('https://nosus.foo/#/join/invite123')),
        'invite123',
      );
    });

    test(
      'parses invite code from hash fragment (legacy GitHub Pages link)',
      () {
        expect(
          extractInviteToken(
            Uri.parse(
              'https://https-shubhamsahu.github.io/NON_SUS/#/join/invite123',
            ),
          ),
          'invite123',
        );
      },
    );

    test('parses invite code from path', () {
      expect(
        extractInviteToken(Uri.parse('https://nosus.app/join/inviteABC')),
        'inviteABC',
      );
    });

    test('parses invite code from path segments for deep links', () {
      expect(
        extractInviteToken(Uri.parse('io.supabase.nosus://join/inviteXYZ')),
        'inviteXYZ',
      );
    });

    test('parses invite code from host/segments for custom schemes', () {
      expect(
        extractInviteToken(Uri.parse('foo.nosus.app://join/inviteDEF')),
        'inviteDEF',
      );
    });

    test('returns null when absent', () {
      expect(extractInviteToken(Uri.parse('https://nosus.app/v/tok9')), isNull);
    });
  });

  group('extractBurnFileToken', () {
    test('parses id/key/iv from the hash fragment', () {
      final uri = Uri.parse(
        'https://nosus.foo/#/burnfile/$noteId?k=$keyHex&v=$ivHex',
      );
      final token = extractBurnFileToken(uri);
      expect(token, isNotNull);
      expect(token!.id, noteId);
      expect(token.keyHex, keyHex);
      expect(token.ivHex, ivHex);
    });

    test('does not collide with the burnfile/ vs burn/ prefix', () {
      // "burnfile/" contains "burn" but never "burn/" (no slash immediately
      // after "burn") — must not be picked up by extractBurnNoteToken, and
      // extractBurnFileToken must not match a plain burn note link either.
      final burnFileUri = Uri.parse(
        'https://nosus.foo/#/burnfile/$noteId?k=$keyHex&v=$ivHex',
      );
      expect(extractBurnNoteToken(burnFileUri), isNull);

      final burnNoteUri = Uri.parse(
        'https://nosus.foo/#/burn/$noteId?k=$keyHex&v=$ivHex',
      );
      expect(extractBurnFileToken(burnNoteUri), isNull);
    });

    test('rejects wrong-length key/iv', () {
      final uri = Uri.parse(
        'https://nosus.foo/#/burnfile/$noteId?k=deadbeef&v=$ivHex',
      );
      expect(extractBurnFileToken(uri), isNull);
    });

    test('returns null on ordinary app URLs', () {
      expect(extractBurnFileToken(Uri.parse('https://nosus.foo/')), isNull);
      expect(extractBurnFileToken(Uri.parse('file:///')), isNull);
    });
  });

  group('extractBurnFilesToken', () {
    const noteId2 = 'fedcba98-7654-3210-fedc-ba9876543210';
    const keyHex2 =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc'; // 64
    const ivHex2 = 'dddddddddddddddddddddddddddddddd'; // 32

    test('parses a two-file batch from the hash fragment', () {
      final uri = Uri.parse(
        'https://app.nosus.foo/#/burnfiles/$noteId,$noteId2?k=$keyHex,$keyHex2&v=$ivHex,$ivHex2',
      );
      final tokens = extractBurnFilesToken(uri);
      expect(tokens, isNotNull);
      expect(tokens!.length, 2);
      expect(tokens[0].id, noteId);
      expect(tokens[0].keyHex, keyHex);
      expect(tokens[0].ivHex, ivHex);
      expect(tokens[1].id, noteId2);
      expect(tokens[1].keyHex, keyHex2);
      expect(tokens[1].ivHex, ivHex2);
    });

    test('does not collide with the singular burnfile/ link, and vice versa', () {
      // The two routes must stay structurally disjoint so a link generated
      // under one format is never silently reinterpreted by the other.
      final singleUri = Uri.parse(
        'https://app.nosus.foo/#/burnfile/$noteId?k=$keyHex&v=$ivHex',
      );
      expect(extractBurnFilesToken(singleUri), isNull);

      final batchUri = Uri.parse(
        'https://app.nosus.foo/#/burnfiles/$noteId,$noteId2?k=$keyHex,$keyHex2&v=$ivHex,$ivHex2',
      );
      expect(extractBurnFileToken(batchUri), isNull);
    });

    test('rejects mismatched id/key/iv list lengths', () {
      final uri = Uri.parse(
        'https://app.nosus.foo/#/burnfiles/$noteId,$noteId2?k=$keyHex&v=$ivHex,$ivHex2',
      );
      expect(extractBurnFilesToken(uri), isNull);
    });

    test('returns null on ordinary app URLs', () {
      expect(
        extractBurnFilesToken(Uri.parse('https://app.nosus.foo/')),
        isNull,
      );
      expect(extractBurnFilesToken(Uri.parse('file:///')), isNull);
    });
  });

  group('extractRedemptionToken', () {
    const redemptionToken =
        '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';

    test('parses a two-digit pairing link from the hash fragment', () {
      expect(
        extractRedemptionToken(
          Uri.parse('https://app.nosus.foo/#/redeem/$redemptionToken'),
        ),
        redemptionToken,
      );
    });

    test('parses a path-style pairing link', () {
      expect(
        extractRedemptionToken(
          Uri.parse('https://app.nosus.foo/redeem/$redemptionToken'),
        ),
        redemptionToken,
      );
    });

    test('rejects non-secret pairing values', () {
      expect(
        extractRedemptionToken(Uri.parse('https://app.nosus.foo/#/redeem/42')),
        isNull,
      );
      expect(
        extractRedemptionToken(
          Uri.parse('https://app.nosus.foo/#/burn/$noteId'),
        ),
        isNull,
      );
    });
  });
}
