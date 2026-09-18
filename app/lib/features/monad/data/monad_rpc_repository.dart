import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/monad_receipt.dart';
import '../domain/monad_repository.dart';

class MonadRpcRepository implements MonadRepository {
  MonadRpcRepository({
    http.Client? client,
    String? contractAddress,
    Uri? rpcUrl,
  }) : _client = client ?? http.Client(),
       _contract =
           contractAddress ??
           const String.fromEnvironment('MONAD_DROPS_CONTRACT'),
       _rpc = rpcUrl ?? Uri.parse('https://testnet-rpc.monad.xyz');
  final http.Client _client;
  final String _contract;
  final Uri _rpc;

  @override
  bool get isConfigured =>
      RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(_contract) &&
      _contract.toLowerCase() != MonadReceipt.zeroAddress;

  Future<String> _call(String method, List<Object> params) async {
    final response = await _client
        .post(
          _rpc,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'method': method,
            'params': params,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('Monad is unavailable. Try again shortly.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['id'] != 1 ||
        decoded['error'] != null ||
        decoded['result'] is! String) {
      throw StateError(
        'No receipt could be verified. Check the ID and try again.',
      );
    }
    return decoded['result'] as String;
  }

  @override
  Future<MonadReceipt> receiptOf(String id) async {
    final dropId = parseMonadDropId(id);
    if (dropId == null) {
      throw const FormatException('Enter a valid Monad receipt ID.');
    }
    if (!isConfigured) {
      throw StateError('The testnet receipt contract is not deployed yet.');
    }
    final chain = await _call('eth_chainId', const []);
    if (BigInt.tryParse(chain.replaceFirst('0x', ''), radix: 16) !=
        BigInt.from(10143)) {
      throw StateError('This experiment requires Monad testnet (10143).');
    }
    final code = await _call('eth_getCode', [_contract, 'latest']);
    if (code == '0x' || code == '0x0') {
      throw StateError('No contract exists at the configured address.');
    }
    final data = await _call('eth_call', [
      {'to': _contract, 'data': '0x72a41fdd${dropId.substring(2)}'},
      'latest',
    ]);
    return MonadReceipt.fromAbi(dropId, data);
  }

  void dispose() => _client.close();
}
