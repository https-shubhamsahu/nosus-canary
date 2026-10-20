// SolanaReceiptClient against saved devnet getTransaction responses. Offline:
// the http client is a MockClient and never reaches the network.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nosus_receipts/nosus_receipts.dart';
import 'package:test/test.dart';

import 'vectors.dart';

const _rpc = 'http://rpc.test';

/// Answers every request with [body] and records the request bodies.
(SolanaReceiptClient, List<Object?>) _client(Object? body, {int status = 200}) {
  final requests = <Object?>[];
  final mock = MockClient((req) async {
    expect(req.url.toString(), _rpc);
    requests.add(jsonDecode(req.body));
    return http.Response(jsonEncode(body), status);
  });
  return (SolanaReceiptClient(_rpc, client: mock), requests);
}

Map<String, dynamic> get _seal =>
    readVector((section('devnet').first)['fixture'] as String);

/// A copy of the seal fixture with its single instruction replaced.
Map<String, dynamic> _withInstruction(Object ix) {
  final copy = _seal;
  ((copy['result'] as Map)['transaction'] as Map)['message']['instructions'] = [
    ix,
  ];
  return copy;
}

Matcher _fails<T>(String message) =>
    throwsA(isA<T>().having((e) => '$e', 'message', contains(message)));

void main() {
  final sig = section('devnet').first['signature'] as String;

  test('fetch decodes every real devnet receipt', () async {
    for (final v in section('devnet')) {
      final (client, _) = _client(readVector(v['fixture'] as String));
      final r = await client.fetch(v['signature'] as String);
      expect(r.signature, v['signature']);
      expect(r.slot, v['slot']);
      expect(r.blockTime, v['blockTime']);
      expect(r.feePayer, v['feePayer']);
      expect(r.memoProgram, v['memoProgram']);
      expect(r.receipt.encode(), v['memo']);
    }
  });

  test('fetch sends one jsonParsed getTransaction at confirmed', () async {
    final (client, requests) = _client(_seal);
    await client.fetch(sig);
    expect(requests, [
      {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'getTransaction',
        'params': [
          sig,
          {
            'encoding': 'jsonParsed',
            'maxSupportedTransactionVersion': 0,
            'commitment': 'confirmed',
          },
        ],
      },
    ]);
  });

  test(
    'fetch reads base58 data from memo programs the node does not parse',
    () async {
      final raw = vectors['rawMemoInstruction'] as Map<String, dynamic>;
      final (client, _) = _client(
        _withInstruction({
          'accounts': [section('devnet').first['feePayer']],
          'data': raw['data'],
          'programId': raw['programId'],
          'stackHeight': 1,
        }),
      );
      final r = await client.fetch(sig);
      expect(r.memoProgram, raw['programId']);
      expect(r.receipt.encode(), raw['memo']);
    },
  );

  test('fetch errors', () async {
    final memoIx = Map<String, dynamic>.from(
      (((_seal['result'] as Map)['transaction'] as Map)['message']
              as Map)['instructions'][0]
          as Map,
    );
    final failed = _seal;
    (failed['result'] as Map)['meta']['err'] = {
      'InstructionError': [0, 'Custom'],
    };
    final twice = _seal;
    ((twice['result'] as Map)['transaction'] as Map)['message']['instructions']
        .add(memoIx);
    final v2 = section('invalidMemos').firstWhere((v) => v['name'] == 'v=2');

    final cases = <(Object?, int, Matcher)>[
      (
        {'jsonrpc': '2.0', 'result': null, 'id': 1},
        200,
        _fails<ReceiptFetchException>(
          'transaction $sig not found on this cluster',
        ),
      ),
      (
        {
          'jsonrpc': '2.0',
          'error': {'code': -32602, 'message': 'Invalid param'},
          'id': 1,
        },
        200,
        _fails<ReceiptFetchException>('getTransaction failed: Invalid param'),
      ),
      (<String, Object>{}, 503, _fails<ReceiptFetchException>('HTTP 503')),
      (
        failed,
        200,
        _fails<ReceiptFetchException>('transaction $sig failed on chain'),
      ),
      (
        _withInstruction({
          'parsed': {'type': 'transfer', 'info': <String, Object>{}},
          'program': 'system',
          'programId': '11111111111111111111111111111111',
        }),
        200,
        _fails<ReceiptFetchException>(
          'transaction $sig has no memo instruction',
        ),
      ),
      (
        _withInstruction({...memoIx, 'parsed': 'gm'}),
        200,
        _fails<ReceiptFetchException>(
          'transaction $sig memo is not a NO SUS Canary receipt',
        ),
      ),
      (
        twice,
        200,
        _fails<ReceiptFetchException>('more than one NO SUS Canary memo'),
      ),
      (
        _withInstruction({...memoIx, 'parsed': v2['memo']}),
        200,
        _fails<ReceiptFormatException>(v2['error'] as String),
      ),
    ];
    for (final (body, status, matcher) in cases) {
      final (client, _) = _client(body, status: status);
      await expectLater(client.fetch(sig), matcher);
    }

    final (client, _) = _client(<String, Object>{});
    await expectLater(
      client.fetch('not a signature!'),
      _fails<ReceiptFetchException>(
        'signature must be a base58 transaction signature',
      ),
    );
  });
}
