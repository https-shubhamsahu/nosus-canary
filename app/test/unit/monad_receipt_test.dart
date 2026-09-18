import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:no_sus/features/monad/domain/monad_receipt.dart';
import 'package:no_sus/features/monad/data/monad_rpc_repository.dart';

void main() {
  final id = '0x${'ab' * 32}';
  final sender = '0x${'11' * 20}';
  final recipient = '0x${'22' * 20}';
  final contract = '0x${'33' * 20}';
  String abi({bool opened = false}) =>
      '0x${[sender.substring(2).padLeft(64, '0'), recipient.substring(2).padLeft(64, '0'), (opened ? recipient.substring(2) : '0').padLeft(64, '0'), 'cd' * 32, 100.toRadixString(16).padLeft(64, '0'), (opened ? 150 : 0).toRadixString(16).padLeft(64, '0'), 200.toRadixString(16).padLeft(64, '0')].join()}';

  test('only accepts receipt IDs and experiment receipt links', () {
    expect(parseMonadDropId(' $id '), id);
    expect(parseMonadDropId('https://monad.nosus.foo/#/monad/$id'), id);
    for (final input in [
      'https://app.nosus.foo/#/monad/$id',
      'https://monad.nosus.foo/#/burn/$id?k=secret',
      '$id?k=secret',
      'https://monad.nosus.foo/#/monad/$id?k=secret',
      '0x123',
      'https://evil.example/#/monad/$id',
    ]) {
      expect(parseMonadDropId(input), isNull);
    }
  });
  test('receipt keeps acknowledgement evidence after exact expiry', () {
    final receipt = MonadReceipt.fromAbi(id, abi(opened: true));
    expect(receipt.sender, sender);
    expect(receipt.opener, recipient);
    expect(
      receipt.status(DateTime.fromMillisecondsSinceEpoch(199999)),
      'Acknowledged',
    );
    expect(
      receipt.status(DateTime.fromMillisecondsSinceEpoch(200000)),
      'Acknowledged · access expired',
    );
  });
  test('rejects malformed or nonexistent receipts', () {
    for (final value in [
      '0x',
      '0x${'0' * 448}',
      '${abi()}00',
      abi().replaceFirst('0000', 'ffff'),
    ]) {
      expect(() => MonadReceipt.fromAbi(id, value), throwsFormatException);
    }
  });
  test('RPC verifies testnet and bytecode before reading receipt', () async {
    final methods = <String>[];
    final client = MockClient((request) async {
      final call = jsonDecode(request.body) as Map<String, dynamic>;
      methods.add(call['method'] as String);
      final result = switch (call['method']) {
        'eth_chainId' => '0x279f',
        'eth_getCode' => '0x6000',
        'eth_call' => abi(opened: true),
        _ => throw StateError('Unexpected RPC call'),
      };
      if (call['method'] == 'eth_call') {
        expect(call['params'][0], {
          'to': contract,
          'data': '0x72a41fdd${id.substring(2)}',
        });
      }
      return http.Response(
        jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': result}),
        200,
      );
    });
    final repository = MonadRpcRepository(
      client: client,
      contractAddress: contract,
    );
    addTearDown(repository.dispose);
    expect((await repository.receiptOf(id)).acknowledged, isTrue);
    expect(methods, ['eth_chainId', 'eth_getCode', 'eth_call']);
  });
  test('wrong chain, missing bytecode and RPC errors fail closed', () async {
    for (final mode in ['wrong-chain', 'no-code', 'error']) {
      final client = MockClient((request) async {
        final method = jsonDecode(request.body)['method'];
        return http.Response(
          jsonEncode(
            mode == 'error'
                ? {
                    'id': 1,
                    'error': {'message': 'revert'},
                  }
                : {
                    'id': 1,
                    'result': method == 'eth_chainId'
                        ? (mode == 'wrong-chain' ? '0x8f' : '0x279f')
                        : '0x',
                  },
          ),
          200,
        );
      });
      final repository = MonadRpcRepository(
        client: client,
        contractAddress: contract,
      );
      addTearDown(repository.dispose);
      await expectLater(repository.receiptOf(id), throwsStateError);
    }
  });
  test('unconfigured contract makes no network calls', () async {
    final repository = MonadRpcRepository(
      client: MockClient(
        (_) async => throw StateError('Unexpected network call'),
      ),
    );
    addTearDown(repository.dispose);
    expect(repository.isConfigured, isFalse);
    await expectLater(repository.receiptOf(id), throwsStateError);
  });
}
