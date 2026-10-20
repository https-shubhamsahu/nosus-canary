// Reads one receipt back from the chain with a plain JSON-RPC getTransaction
// call.

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'memo.dart';

/// A receipt as read from the chain.
class FetchedReceipt {
  const FetchedReceipt({
    required this.signature,
    required this.slot,
    required this.blockTime,
    required this.feePayer,
    required this.memoProgram,
    required this.receipt,
  });

  final String signature;
  final int slot;

  /// Unix seconds; null when the node does not know it.
  final int? blockTime;

  /// First account key: the relayer that paid for and signed the memo.
  final String feePayer;
  final String memoProgram;
  final ReceiptMemo receipt;
}

/// The transaction could not be read, or carries no NO SUS Canary receipt.
class ReceiptFetchException implements Exception {
  const ReceiptFetchException(this.message);

  final String message;

  @override
  String toString() => 'ReceiptFetchException: $message';
}

final _signature = RegExp(r'^[1-9A-HJ-NP-Za-km-z]{64,88}$');
const _base58 = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

class SolanaReceiptClient {
  /// [client] is closed by [close] only when this class created it.
  SolanaReceiptClient(this.rpcUrl, {http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final String rpcUrl;
  final http.Client _client;
  final bool _ownsClient;

  /// Fetches a transaction and decodes its NO SUS Canary memo. Throws
  /// [ReceiptFetchException] when the transaction is missing or failed, has
  /// no memo or a foreign memo, and [ReceiptFormatException] when the memo is
  /// not exactly format v1.
  Future<FetchedReceipt> fetch(String signature) async {
    if (!_signature.hasMatch(signature)) {
      throw const ReceiptFetchException(
        'signature must be a base58 transaction signature',
      );
    }
    final res = await _client.post(
      Uri.parse(rpcUrl),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'getTransaction',
        'params': [
          signature,
          {
            'encoding': 'jsonParsed',
            'maxSupportedTransactionVersion': 0,
            'commitment': 'confirmed',
          },
        ],
      }),
    );
    if (res.statusCode < 200 || res.statusCode > 299) {
      throw ReceiptFetchException(
        'getTransaction failed: HTTP ${res.statusCode}',
      );
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final error = body['error'];
    if (error != null) {
      final message = error is Map ? error['message'] : null;
      throw ReceiptFetchException(
        'getTransaction failed: ${message ?? 'RPC error'}',
      );
    }

    final tx = body['result'] as Map<String, dynamic>?;
    if (tx == null) {
      throw ReceiptFetchException(
        'transaction $signature not found on this cluster',
      );
    }
    final meta = tx['meta'] as Map<String, dynamic>?;
    if (meta?['err'] != null) {
      throw ReceiptFetchException('transaction $signature failed on chain');
    }

    final message =
        (tx['transaction'] as Map<String, dynamic>)['message']
            as Map<String, dynamic>;
    final memos = [
      for (final ix in (message['instructions'] as List).cast<Map>())
        if (memoProgramIds.contains(ix['programId']))
          (program: ix['programId'] as String, text: _memoText(ix)),
    ];
    if (memos.isEmpty) {
      throw ReceiptFetchException(
        'transaction $signature has no memo instruction',
      );
    }
    final ours = memos
        .where((m) => m.text.startsWith('{"p":"$receiptProtocol",'))
        .toList();
    if (ours.isEmpty) {
      throw ReceiptFetchException(
        'transaction $signature memo is not a NO SUS Canary receipt',
      );
    }
    if (ours.length > 1) {
      throw ReceiptFetchException(
        'transaction $signature has more than one NO SUS Canary memo',
      );
    }

    final keys = message['accountKeys'] as List;
    return FetchedReceipt(
      signature: signature,
      slot: tx['slot'] as int,
      blockTime: tx['blockTime'] as int?,
      feePayer: keys.isEmpty ? '' : (keys.first as Map)['pubkey'] as String,
      memoProgram: ours.single.program,
      receipt: ReceiptMemo.parse(ours.single.text),
    );
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

// RPC nodes decode SPL Memo v1/v3 into `parsed`; other memo programs (p-memo)
// come back as base58 `data`.
String _memoText(Map ix) {
  final parsed = ix['parsed'];
  if (parsed is String) return parsed;
  final data = ix['data'];
  if (data is String) {
    return utf8.decode(_base58Decode(data), allowMalformed: true);
  }
  return '';
}

List<int> _base58Decode(String text) {
  var n = BigInt.zero;
  for (final c in text.split('')) {
    final digit = _base58.indexOf(c);
    if (digit < 0) throw const ReceiptFetchException('memo data is not base58');
    n = n * BigInt.from(58) + BigInt.from(digit);
  }
  final bytes = <int>[];
  for (; n > BigInt.zero; n = n >> 8) {
    bytes.add((n & BigInt.from(0xff)).toInt());
  }
  // Each leading "1" is a leading zero byte.
  final zeros = text.length - text.replaceFirst(RegExp('^1+'), '').length;
  return [...List.filled(zeros, 0), ...bytes.reversed];
}
