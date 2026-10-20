// Verify a NO SUS Canary receipt from the command line:
//   dart run bin/verify.dart <signature> [--cluster devnet|mainnet-beta] [--rpc URL] [--note <uuid>]
// Prints the decoded receipt and its Explorer link. With --note, also checks
// that the memo's note equals sha256("nosus-canary:" + uuid); exit 1 if not.
// Exit codes: 0 ok, 1 receipt error or note mismatch, 2 bad usage.

import 'dart:io';

import 'package:nosus_receipts/nosus_receipts.dart';

const _usage =
    'usage: dart run bin/verify.dart <signature> '
    '[--cluster devnet|mainnet-beta] [--rpc URL] [--note <uuid>]';
final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

Future<void> main(List<String> args) async => exitCode = await _run(args);

String _time(int seconds) => DateTime.fromMillisecondsSinceEpoch(
  seconds * 1000,
  isUtc: true,
).toIso8601String().replaceFirst('.000Z', 'Z');

Future<int> _run(List<String> args) async {
  final opts = <String, String>{};
  final positional = <String>[];
  for (var i = 0; i < args.length; i++) {
    final eq = args[i].indexOf('=');
    final flag = eq < 0 ? args[i] : args[i].substring(0, eq);
    if (flag == '-h' || flag == '--help') {
      stdout.writeln(_usage);
      return 0;
    }
    if (!flag.startsWith('-')) {
      positional.add(args[i]);
      continue;
    }
    if (!const ['--cluster', '--rpc', '--note'].contains(flag)) {
      return _bad('unknown option $flag');
    }
    final value = eq >= 0
        ? args[i].substring(eq + 1)
        : (++i < args.length ? args[i] : null);
    if (value == null) return _bad('$flag needs a value');
    opts[flag.substring(2)] = value;
  }
  if (positional.length != 1) {
    return _bad('give exactly one transaction signature');
  }
  final cluster = SolanaCluster.byId(opts['cluster'] ?? 'devnet');
  if (cluster == null) return _bad('--cluster must be devnet or mainnet-beta');
  final note = opts['note']?.toLowerCase();
  if (note != null && !_uuid.hasMatch(note)) {
    return _bad('--note must be a note UUID');
  }

  final client = SolanaReceiptClient(opts['rpc'] ?? cluster.rpcUrl);
  final FetchedReceipt r;
  try {
    r = await client.fetch(positional.single);
  } on Exception catch (e) {
    stderr.writeln(
      'error: ${switch (e) {
        ReceiptFetchException(:final message) => message,
        FormatException(:final message) => message,
        _ => '$e',
      }}',
    );
    return 1;
  } finally {
    client.close();
  }

  final rc = r.receipt;
  final rows = <(String, Object)>[
    ('signature', r.signature),
    ('slot', r.slot),
    ('time', r.blockTime == null ? 'unknown' : _time(r.blockTime!)),
    ('fee payer', r.feePayer),
    ('program', r.memoProgram),
    ('note', rc.note),
    ...switch (rc) {
      SealReceipt(:final copies, :final hash, :final exp) => [
        ('copies', copies),
        ('hash', hash),
        ('expires', exp == 0 ? 'never (0)' : '${_time(exp)} ($exp)'),
      ],
      OpenReceipt(:final copy, :final tag) => [('copy', copy), ('tag', tag)],
    },
    ('explorer', explorerTxUrl(r.signature, cluster: cluster)),
  ];
  stdout.writeln('NO SUS Canary ${rc.type} receipt (format v$receiptVersion)');
  for (final (k, v) in rows) {
    stdout.writeln('  ${k.padRight(10)} $v');
  }

  if (note != null) {
    final expected = chainNoteId(note);
    if (expected != rc.note) {
      stderr.writeln('note check: MISMATCH. chainNoteId($note) is $expected');
      return 1;
    }
    stdout.writeln('note check: ok, sha256("nosus-canary:$note") matches');
  }
  return 0;
}

int _bad(String problem) {
  stderr.writeln('$problem\n$_usage');
  return 2;
}
